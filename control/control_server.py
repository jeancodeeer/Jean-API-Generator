#!/usr/bin/env python3
"""Servidor de control de Jean-API-Generator (puerto 8899).

Permite a un cliente (JeanCode) cargar cualquier GGUF de Hugging Face en uno de los puertos
de modelo del Codespace, sin entrar al Codespace. Solo biblioteca estandar.

  GET  /status                  modelos por puerto, disco, RAM y descargas en curso
  POST /load    {repo, file, slot, hf_token?, ctx?}   descarga y sirve el GGUF en ese puerto
  POST /restore {slot}          vuelve a servir el modelo Jean original de ese puerto
  GET  /jobs/<id>               progreso de una descarga
  GET|POST /relay/<host>/<ruta>  relay CORS hacia APIs conocidas (X-Jean-Key = JEAN_API_KEY)
  GET  /health                  publico: {"ok": true, "ready": N} (sin datos del sistema)
  GET  /v1/models  POST /v1/chat/completions ...   router OpenAI-compatible (ver router.py):
                                una sola URL para todos los modelos del Codespace

Seguridad: toda peticion (salvo OPTIONS) exige "Authorization: Bearer $JEAN_API_KEY".
El token de HF, si se envia, solo se usa para esa descarga y nunca se guarda en disco.
Los modelos personalizados viven en gguf/custom/ y en /tmp/jean-slot-<puerto>.env; al reiniciar
el Codespace vuelven los modelos Jean de siempre.
"""
import hmac
import json
import os
import re
import shutil
import subprocess
import threading
import time
import urllib.request
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import router  # noqa: E402  (mismo directorio)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GGDIR = os.path.join(ROOT, "gguf")
CUSTOM_DIR = os.path.join(GGDIR, "custom")
KEY = os.environ.get("JEAN_API_KEY", "")
PORT = int(os.environ.get("JEAN_CONTROL_PORT", "8899"))
# puertos de modelo; JEAN_SLOTS="8888:grey,8889:marvel" solo para pruebas o maquinas propias
SLOTS = {int(p): m for p, m in (x.split(":", 1) for x in os.environ.get("JEAN_SLOTS", "").split(",") if ":" in x)} \
    or {8888: "grey", 8889: "marvel", 8890: "fenix"}
REPO_RE = re.compile(r"^[A-Za-z0-9][\w.-]{0,95}/[\w.-]{1,96}$")
FILE_RE = re.compile(r"^[\w][\w./-]{0,250}\.gguf$")
JOBS = {}
LOCK = threading.Lock()
TABLE = router.SlotTable(list(SLOTS), KEY)
RELAY_HOSTS = router.relay_hosts(os.environ.get("JEAN_RELAY_HOSTS", ""))
RELAY_LOCAL_HTTP = os.environ.get("JEAN_RELAY_TEST_LOCAL_HTTP") == "1"  # solo pruebas


def slot_status_path(slot):
    """serve.sh escribe aqui por que un puerto no pudo arrancar (p. ej. Fenix no cabe en la RAM)."""
    return f"/tmp/jean-slot-{slot}.status"


def slot_notes():
    notes = {}
    for slot in SLOTS:
        try:
            with open(slot_status_path(slot), encoding="utf-8") as f:
                notes[slot] = f.read(300).strip()
        except OSError:
            pass
    return notes


def log(*a):
    print(time.strftime("[control %H:%M:%S]"), *a, flush=True)


def meminfo():
    """RAM del sistema (Linux). Vacio si no hay /proc: entonces no se comprueba la RAM."""
    out = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                out[k] = int(v.split()[0]) * 1024
    except OSError:
        pass
    return out


def slot_env_path(slot):
    return f"/tmp/jean-slot-{slot}.env"


def slot_lock_path(slot):
    return f"/tmp/jean-slot-{slot}.lock"


def read_env(slot):
    p = slot_env_path(slot)
    if not os.path.exists(p):
        return {}
    env = {}
    for line in open(p, encoding="utf-8"):
        if "=" in line:
            k, v = line.rstrip("\n").split("=", 1)
            env[k] = v
    return env


def server_running(slot):
    return subprocess.run(["pgrep", "-f", f"llama-server.*--port {slot}"], capture_output=True).returncode == 0


def served_models(slot):
    try:
        req = urllib.request.Request(f"http://127.0.0.1:{slot}/v1/models", headers={"Authorization": f"Bearer {KEY}"})
        with urllib.request.urlopen(req, timeout=5) as r:
            return [m.get("id") for m in json.loads(r.read()).get("data", [])]
    except Exception as e:
        return [f"(no responde: {type(e).__name__})"]


def hf_file_size(repo, file, token):
    url = f"https://huggingface.co/api/models/{repo}/tree/main?recursive=true"
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
        for item in json.loads(r.read()):
            if item.get("path") == file:
                lfs = item.get("lfs") or {}
                return int(lfs.get("size") or item.get("size") or 0)
    raise ValueError(f"{file} no existe en {repo} (o el repo es privado y falta el token)")


def stop_slot(slot):
    subprocess.run(["pkill", "-f", f"llama-server.*--port {slot}"])
    for _ in range(30):
        if not server_running(slot):
            return
        time.sleep(1)


def launch(slot, env_extra, model):
    env = dict(os.environ, PORT=str(slot), JEAN_GGUF_DIR=GGDIR, **env_extra)
    logf = open(f"/tmp/serve-{model}.log", "a")
    subprocess.Popen(["setsid", "nohup", "bash", os.path.join(ROOT, "serve.sh"), model],
                     env=env, stdout=logf, stderr=logf, stdin=subprocess.DEVNULL)


def wait_healthy(slot, timeout=900):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{slot}/health", timeout=5) as r:
                if r.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(5)
    return False


def alias_for(repo, file):
    base = os.path.basename(file)[:-5].lower()
    return re.sub(r"[^a-z0-9._-]+", "-", base)[:64]


def load_job(job):
    slot, repo, file, token = job["slot"], job["repo"], job["file"], job.pop("token", None)
    dest_dir = os.path.join(CUSTOM_DIR, str(slot))
    rel = os.path.join("custom", str(slot), os.path.basename(file))
    dest = os.path.join(GGDIR, rel)
    try:
        open(slot_lock_path(slot), "w").write(job["id"])
        if os.path.isdir(dest_dir):  # un solo modelo personalizado por puerto: se borra el anterior
            for f in os.listdir(dest_dir):
                if os.path.join(dest_dir, f) != dest:
                    os.remove(os.path.join(dest_dir, f))
        os.makedirs(dest_dir, exist_ok=True)
        if not (os.path.exists(dest) and os.path.getsize(dest) == job["size"]):
            job["state"] = "downloading"
            part = dest + ".part"
            if os.path.exists(part):
                os.remove(part)
            cmd = ["curl", "-fL", "--retry", "3", "-o", part, f"https://huggingface.co/{repo}/resolve/main/{file}"]
            if token:
                cmd[1:1] = ["-H", f"Authorization: Bearer {token}"]
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            while proc.poll() is None:
                job["downloaded"] = os.path.getsize(part) if os.path.exists(part) else 0
                time.sleep(2)
            if proc.returncode != 0:
                raise RuntimeError("descarga fallida: " + proc.stderr.read().decode(errors="replace")[-300:])
            os.replace(part, dest)
        job["downloaded"] = job["size"]
        job["state"] = "starting"
        stop_slot(slot)
        alias = job.get("alias") or alias_for(repo, file)
        env = {"CUSTOM_FILE": rel, "CUSTOM_ALIAS": alias, "CUSTOM_CTX": str(int(job.get("ctx") or 16384))}
        # defensa extra: el archivo lo lee watchdog.sh linea a linea (sin ejecutarlo), y aun asi
        # solo se escriben valores con caracteres seguros
        safe = re.compile(r"[A-Za-z0-9._/-]+")
        if not all(safe.fullmatch(v) for v in (*env.values(), repo)):
            raise RuntimeError("valores no seguros para el archivo del puerto")
        with open(slot_env_path(slot), "w", encoding="utf-8") as f:
            f.write("".join(f"{k}={v}\n" for k, v in env.items()) + f"REPO={repo}\n")
        launch(slot, env, "custom")
        if not wait_healthy(slot):
            raise RuntimeError("el modelo no arranco (mira /tmp/serve-custom.log en el Codespace)")
        TABLE.invalidate()
        job.update(state="done", alias=alias)
        log(f"slot {slot}: {repo}/{file} listo como {alias}")
    except Exception as e:
        job.update(state="error", error=str(e)[:500])
        log(f"slot {slot}: error {e}")
    finally:
        if os.path.exists(slot_lock_path(slot)):
            os.remove(slot_lock_path(slot))


class Handler(BaseHTTPRequestHandler):
    server_version = "JeanControl/1"

    def log_message(self, fmt, *args):
        log(self.address_string(), fmt % args)

    def cors(self):
        origin = self.headers.get("Origin")
        self.send_header("Access-Control-Allow-Origin", origin or "*")
        self.send_header("Vary", "Origin")
        self.send_header("Access-Control-Allow-Headers", "authorization, content-type, x-jean-key, x-title, http-referer, anthropic-version")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Expose-Headers", "X-Jean-Model, X-Jean-Port")

    def reply(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authed(self):
        got = self.headers.get("Authorization", "")
        if KEY and hmac.compare_digest(got.encode(), f"Bearer {KEY}".encode()):
            return True
        self.reply(401, {"error": "clave invalida"})
        return False

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 65536:
            raise ValueError("cuerpo demasiado grande")
        return json.loads(self.rfile.read(n) or b"{}")

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def relay_request(self, method):
        """Relay CORS: autentica con X-Jean-Key (Authorization es la clave del proveedor)."""
        got = self.headers.get("X-Jean-Key", "")
        if not (KEY and hmac.compare_digest(got.encode(), KEY.encode())):
            return self.reply(401, {"error": {"message": "X-Jean-Key invalida o ausente (usa tu JEAN_API_KEY).", "type": "jean_relay_auth"}})
        try:
            url = router.relay_target(self.path, RELAY_HOSTS, RELAY_LOCAL_HTTP)
            n = int(self.headers.get("Content-Length") or 0)
            if n > router.MAX_BODY:
                raise router.RouteError(413, "Peticion demasiado grande.", "invalid_request_error")
            body = self.rfile.read(n) if method == "POST" else None
            log(f"relay {method} {url.split('?')[0]}")
            router.relay(self, method, url, body)
        except router.RouteError as e:
            self.reply(e.status, e.body())

    def do_GET(self):
        if self.path.startswith("/relay/"):
            return self.relay_request("GET")
        try:
            self.get()
        except Exception as e:  # nunca cortar la conexion sin respuesta: el cliente veria "no conecta"
            log(f"GET {self.path}: {type(e).__name__}: {e}")
            self.reply(500, {"error": f"{type(e).__name__}: {str(e)[:300]}"})

    def get(self):
        path = self.path.split("?", 1)[0].rstrip("/")
        if path == "/health":
            ready, _ = TABLE.snapshot()
            return self.reply(200, {"ok": bool(ready), "ready": len(ready)})
        if not self.authed():
            return
        if path == "/v1/models":
            ready, down = TABLE.snapshot()
            return self.reply(200, router.models_payload(ready, down, {p: f"jean-{m}" for p, m in SLOTS.items()},
                                                          slot_notes(), TABLE.contexts()))
        if path == "/status":
            mem, du = meminfo(), shutil.disk_usage(GGDIR)
            slots = {}
            for slot, model in SLOTS.items():
                env = read_env(slot)
                slots[str(slot)] = {
                    "default": f"jean-{model}", "custom": env.get("REPO") and f"{env['REPO']}/{os.path.basename(env['CUSTOM_FILE'])}",
                    "running": server_running(slot), "busy": os.path.exists(slot_lock_path(slot)),
                    "models": served_models(slot) if server_running(slot) else [],
                }
            with LOCK:
                jobs = [{k: v for k, v in j.items() if k != "token"} for j in JOBS.values()][-10:]
            return self.reply(200, {"slots": slots, "ram_total": mem.get("MemTotal"), "ram_available": mem.get("MemAvailable"),
                                    "disk_free": du.free, "jobs": jobs})
        m = re.fullmatch(r"/jobs/([0-9a-f-]{36})", self.path)
        if m and m.group(1) in JOBS:
            j = JOBS[m.group(1)]
            return self.reply(200, {k: v for k, v in j.items() if k != "token"})
        self.reply(404, {"error": "ruta desconocida"})

    def proxy(self, path):
        """Router: resuelve el modelo y reenvia al puerto que lo sirve."""
        try:
            n = int(self.headers.get("Content-Length") or 0)
            if n > router.MAX_BODY:
                raise router.RouteError(413, "Peticion demasiado grande.", "invalid_request_error")
            body = self.rfile.read(n)
            ready, _ = TABLE.snapshot()
            model, port = router.resolve(router.requested_model(body), ready)
            _, body = router.rewrite_model(body, model)
            self.extra_headers = {"X-Jean-Model": model}
            log(f"router {path} -> {model} (:{port})")
            router.forward(self, port, path, body, KEY)
        except router.RouteError as e:
            if e.kind == "jean_unavailable":
                TABLE.invalidate()
            log(f"router {path}: {e.status} {e.message}")
            self.reply(e.status, e.body())

    def do_POST(self):
        if self.path.startswith("/relay/"):
            return self.relay_request("POST")
        if not self.authed():
            return
        path = self.path.split("?", 1)[0].rstrip("/")
        if path in router.PROXY_PATHS:
            return self.proxy(path)
        try:
            data = self.body()
            slot = int(data.get("slot", 0))
            if slot not in SLOTS:
                return self.reply(400, {"error": f"slot debe ser uno de {sorted(SLOTS)}"})
            if os.path.exists(slot_lock_path(slot)):
                return self.reply(409, {"error": "ese puerto ya esta cargando un modelo"})
            if self.path.rstrip("/") == "/restore":
                if os.path.exists(slot_env_path(slot)):
                    os.remove(slot_env_path(slot))
                shutil.rmtree(os.path.join(CUSTOM_DIR, str(slot)), ignore_errors=True)
                stop_slot(slot)
                TABLE.invalidate()
                if SLOTS[slot] == "fenix":
                    # Fenix no cabe junto a Grey y Marvel: se activa aparte con fenix-mode
                    return self.reply(202, {"ok": True, "slot": slot, "model": None,
                                            "note": "puerto libre; Fenix se activa con jean-api.ps1 fenix-mode"})
                launch(slot, {}, SLOTS[slot])
                TABLE.invalidate()
                return self.reply(202, {"ok": True, "slot": slot, "model": f"jean-{SLOTS[slot]}"})
            if self.path.rstrip("/") != "/load":
                return self.reply(404, {"error": "ruta desconocida"})
            repo, file = str(data.get("repo", "")), str(data.get("file", ""))
            if not REPO_RE.match(repo) or not FILE_RE.match(file) or ".." in file:
                return self.reply(400, {"error": "repo o archivo invalido (debe ser un .gguf)"})
            token = data.get("hf_token") or None
            # alias y ctx terminan en /tmp/jean-slot-<puerto>.env: solo valores inocuos
            alias = data.get("alias")
            if alias is not None and not re.fullmatch(r"[A-Za-z0-9._-]{1,64}", str(alias)):
                return self.reply(400, {"error": "alias invalido (letras, numeros, . _ -; maximo 64)"})
            try:
                ctx = int(data.get("ctx") or 16384)
            except (TypeError, ValueError):
                return self.reply(400, {"error": "ctx debe ser un entero"})
            if not 512 <= ctx <= 262144:
                return self.reply(400, {"error": "ctx fuera de rango (512-262144)"})
            if token is not None and not re.fullmatch(r"[A-Za-z0-9_-]{8,200}", str(token)):
                return self.reply(400, {"error": "token de Hugging Face con formato invalido"})
            size = hf_file_size(repo, file, token)
            # comprobaciones de espacio: disco (mas 2 GB de margen) y RAM (modelo + ~1.5 GB)
            freed_disk = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(os.path.join(CUSTOM_DIR, str(slot))) for f in fs)
            if size + 2 * 2**30 > shutil.disk_usage(GGDIR).free + freed_disk:
                return self.reply(400, {"error": f"no cabe en disco: necesita {size / 2**30:.1f} GB + 2 GB libres"})
            mem = meminfo()
            current = 0
            env = read_env(slot)
            cur_file = os.path.join(GGDIR, env["CUSTOM_FILE"]) if env.get("CUSTOM_FILE") else os.path.join(GGDIR, f"jean-{SLOTS[slot]}-v0.7.Q4_K_M.gguf")
            if server_running(slot) and os.path.exists(cur_file):
                current = os.path.getsize(cur_file)
            if "MemAvailable" in mem and size * 1.1 + 1.5 * 2**30 > mem["MemAvailable"] + current:
                return self.reply(400, {"error": f"no cabe en RAM: el modelo pesa {size / 2**30:.1f} GB y quedan "
                                                 f"{(mem['MemAvailable'] + current) / 2**30:.1f} GB para ese puerto"})
            job = {"id": str(uuid.uuid4()), "slot": slot, "repo": repo, "file": file, "size": size, "downloaded": 0,
                   "state": "queued", "token": token, "ctx": ctx, "alias": alias, "started": time.time()}
            with LOCK:
                JOBS[job["id"]] = job
            threading.Thread(target=load_job, args=(job,), daemon=True).start()
            self.reply(202, {k: v for k, v in job.items() if k != "token"})
        except ValueError as e:
            self.reply(400, {"error": str(e)})
        except Exception as e:
            self.reply(500, {"error": f"{type(e).__name__}: {str(e)[:300]}"})


if __name__ == "__main__":
    if not KEY:
        raise SystemExit("[control] falta JEAN_API_KEY: no arranco")
    os.makedirs(CUSTOM_DIR, exist_ok=True)
    log(f"escuchando en :{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
