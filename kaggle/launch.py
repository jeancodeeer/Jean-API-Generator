#!/usr/bin/env python3
"""Jean API en un notebook de Kaggle (GPU T4 x2 gratis, sin tarjeta).

Lo llama kaggle/jean-api.ipynb. Hace lo mismo que el Codespace, con GPU:
  1. instala llama.cpp oficial con CUDA (binario publicado, no compila nada);
  2. sirve cada modelo con serve.sh en su puerto (8888, 8889, ...), uno por GPU;
  3. arranca el router (control/control_server.py, :8899) con tu JEAN_API_KEY;
  4. abre un túnel de Cloudflare hacia el router e imprime la URL para JeanCode;
  5. vigila: relanza un modelo o el túnel si se caen y avisa antes de que acabe la sesión.

Modelos (JEAN_MODELS, separados por comas):
  grey | marvel | fenix                  modelos Jean (fenix ocupa las dos GPU)
  hf:usuario/repo/archivo.gguf           cualquier GGUF de Hugging Face (HF_TOKEN si es privado)
  file:/kaggle/input/.../modelo.gguf     un GGUF tuyo, subido como dataset y añadido con "Add Input"

Clave: la del secreto JEAN_API_KEY de Kaggle (fija, nunca se imprime). Sin secreto, se genera una para esta
sesión y se muestra junto a la URL: solo la ve el dueño del notebook y cambia en cada Run All, como la URL.
"""
import json
import os
import secrets
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GGDIR = os.path.join(REPO, "gguf")
WORK = os.environ.get("JEAN_HOME") or ("/kaggle/tmp" if os.path.isdir("/kaggle/tmp") else "/tmp")
LLAMA_DIR = os.path.join(WORK, "llama")
LLAMA_TAG = os.environ.get("JEAN_LLAMA_TAG", "b12388")  # versión fija y probada de llama.cpp
CF_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
ROUTER_PORT = 8899
FIRST_PORT = 8888
JEAN = ("grey", "marvel", "fenix")


def say(msg):
    print(f"[jean {time.strftime('%H:%M:%S')}] {msg}", flush=True)


# ------------------------------------------------------------------ plan
def parse_models(spec):
    """'grey,hf:a/b/c.gguf' -> [{'kind': 'jean'|'hf'|'file', ...}]. Lanza ValueError si algo no es válido."""
    out = []
    for raw in [x.strip() for x in (spec or "grey,marvel").split(",") if x.strip()]:
        if raw.lower() in JEAN:
            out.append({"kind": "jean", "name": raw.lower()})
        elif raw.startswith("hf:"):
            parts = raw[3:].split("/")
            if len(parts) < 3 or not parts[-1].endswith(".gguf"):
                raise ValueError(f"'{raw}': usa hf:usuario/repo/archivo.gguf")
            out.append({"kind": "hf", "repo": "/".join(parts[:2]), "file": "/".join(parts[2:])})
        elif raw.startswith("file:"):
            path = raw[5:]
            if not path.endswith(".gguf"):
                raise ValueError(f"'{raw}': el archivo debe ser .gguf")
            out.append({"kind": "file", "path": path})
        else:
            raise ValueError(f"'{raw}' no es un modelo válido (grey, marvel, fenix, hf:..., file:...)")
    if not out:
        raise ValueError("JEAN_MODELS está vacío")
    return out


def alias_of(m):
    if m["kind"] == "jean":
        return f"jean-{m['name']}"
    base = os.path.basename(m["file"] if m["kind"] == "hf" else m["path"])[:-5].lower()
    return re.sub(r"[^a-z0-9._-]+", "-", base)[:64]


def plan_slots(models, gpus):
    """Asigna puerto y GPU a cada modelo. Fénix (o un único modelo) usa todas las GPU."""
    plan = []
    for i, m in enumerate(models):
        if not gpus:
            gpu = ""
        elif m.get("name") == "fenix" or len(models) == 1:
            gpu = ",".join(str(g) for g in range(gpus))
        else:
            gpu = str(i % gpus)
        plan.append({**m, "port": FIRST_PORT + i, "gpu": gpu, "alias": alias_of(m)})
    ports = [p["port"] for p in plan]
    if ROUTER_PORT in ports:
        raise ValueError("demasiados modelos: como máximo 11")
    return plan


# ------------------------------------------------------------------ instalación
def count_gpus():
    try:
        out = subprocess.run(["nvidia-smi", "-L"], capture_output=True, text=True, timeout=20).stdout
        return len([l for l in out.splitlines() if l.startswith("GPU ")])
    except (OSError, subprocess.SubprocessError):
        return 0


def download(url, dst):
    tmp = dst + ".part"
    req = urllib.request.Request(url, headers={"User-Agent": "jean-api-generator"})
    with urllib.request.urlopen(req, timeout=120) as r, open(tmp, "wb") as f:
        shutil.copyfileobj(r, f, 1 << 20)
    os.replace(tmp, dst)


def extract(tgz, dst):
    with tarfile.open(tgz) as t:
        try:
            t.extractall(dst, filter="data")
        except TypeError:  # Python sin el parámetro filter
            t.extractall(dst)


def find_bin(root):
    for d, _, files in os.walk(root):
        if "llama-server" in files:
            return os.path.join(d, "llama-server")
    return None


def missing_libs(binary):
    out = subprocess.run(["ldd", binary], capture_output=True, text=True).stdout
    return [l.split()[0] for l in out.splitlines() if "not found" in l]


def install_llama(gpus):
    os.makedirs(LLAMA_DIR, exist_ok=True)
    bin_path = find_bin(LLAMA_DIR)
    if bin_path:
        return bin_path
    base = f"https://github.com/ggml-org/llama.cpp/releases/download/{LLAMA_TAG}/"
    name = f"llama-{LLAMA_TAG}-bin-ubuntu-cuda-12.8-x64.tar.gz" if gpus else f"llama-{LLAMA_TAG}-bin-ubuntu-x64.tar.gz"
    say(f"instalando llama.cpp {LLAMA_TAG} ({'CUDA' if gpus else 'CPU'}) ...")
    tgz = os.path.join(LLAMA_DIR, name)
    download(base + name, tgz)
    extract(tgz, LLAMA_DIR)
    os.remove(tgz)
    bin_path = find_bin(LLAMA_DIR)
    if not bin_path:
        raise RuntimeError("el paquete de llama.cpp no trae llama-server")
    lib_dir = os.path.dirname(bin_path)
    os.environ["LD_LIBRARY_PATH"] = lib_dir + ":" + os.environ.get("LD_LIBRARY_PATH", "")
    if gpus and missing_libs(bin_path):
        say("faltan bibliotecas de CUDA: bajando el runtime oficial (cudart) ...")
        rt = os.path.join(LLAMA_DIR, "cudart.tar.gz")
        download(base + f"cudart-llama-{LLAMA_TAG}-bin-ubuntu-cuda-12.8-x64.tar.gz", rt)
        extract(rt, lib_dir)
        os.remove(rt)
    still = missing_libs(bin_path)
    if still:
        raise RuntimeError(f"llama-server no puede arrancar, faltan: {', '.join(still)}")
    return bin_path


def install_cloudflared():
    path = os.path.join(WORK, "cloudflared")
    if not os.path.exists(path):
        download(CF_URL, path)
        os.chmod(path, 0o755)
    return path


def prepare_custom(slot):
    """Deja el GGUF de un modelo hf:/file: en gguf/custom/<puerto>/ y devuelve la ruta relativa."""
    d = os.path.join(GGDIR, "custom", str(slot["port"]))
    os.makedirs(d, exist_ok=True)
    if slot["kind"] == "file":
        if not os.path.isfile(slot["path"]):
            raise RuntimeError(f"no existe {slot['path']}: añádelo al notebook con «Add Input»")
        dst = os.path.join(d, os.path.basename(slot["path"]))
        if not os.path.exists(dst):
            os.symlink(slot["path"], dst)
    else:
        dst = os.path.join(d, os.path.basename(slot["file"]))
        if not os.path.exists(dst):
            say(f"bajando {slot['repo']}/{slot['file']} ...")
            url = f"https://huggingface.co/{slot['repo']}/resolve/main/{slot['file']}"
            hdr = {"User-Agent": "jean-api-generator"}
            if os.environ.get("HF_TOKEN"):
                hdr["Authorization"] = f"Bearer {os.environ['HF_TOKEN']}"
            tmp = dst + ".part"
            with urllib.request.urlopen(urllib.request.Request(url, headers=hdr), timeout=120) as r, open(tmp, "wb") as f:
                shutil.copyfileobj(r, f, 1 << 22)
            os.replace(tmp, dst)
    return os.path.relpath(dst, GGDIR)


# ------------------------------------------------------------------ procesos
def start_model(slot, binary, ctx):
    env = dict(os.environ, PORT=str(slot["port"]), JEAN_LLAMA_BIN=binary, JEAN_GGUF_DIR=GGDIR,
               JEAN_CTX=str(ctx), JEAN_THREADS=os.environ.get("JEAN_THREADS", "4"))
    if slot["gpu"]:
        env.update(JEAN_NGL="99", JEAN_GPU=slot["gpu"])
    model = slot.get("name", "custom")
    if slot["kind"] != "jean":
        env.update(CUSTOM_FILE=slot["custom_file"], CUSTOM_ALIAS=slot["alias"], CUSTOM_CTX=str(ctx))
        model = "custom"
    log = open(os.path.join(WORK, f"serve-{slot['port']}.log"), "a")
    return subprocess.Popen(["bash", os.path.join(REPO, "serve.sh"), model], env=env,
                            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)


def start_router(plan, binary, gpus):
    # los modelos que cargues desde JeanCode (panel de Hugging Face) también van a la GPU
    env = dict(os.environ, JEAN_CONTROL_PORT=str(ROUTER_PORT), JEAN_LLAMA_BIN=binary,
               JEAN_THREADS=os.environ.get("JEAN_THREADS", "4"), **({"JEAN_NGL": "99"} if gpus else {}),
               JEAN_SLOTS=",".join(f"{s['port']}:{s.get('name', 'custom')}" for s in plan))
    log = open(os.path.join(WORK, "router.log"), "a")
    return subprocess.Popen([sys.executable, os.path.join(REPO, "control", "control_server.py")], env=env,
                            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)


def start_tunnel(cf):
    log_path = os.path.join(WORK, "tunnel.log")
    open(log_path, "w").close()
    proc = subprocess.Popen([cf, "tunnel", "--url", f"http://127.0.0.1:{ROUTER_PORT}", "--no-autoupdate"],
                            stdout=open(log_path, "a"), stderr=subprocess.STDOUT, start_new_session=True)
    for _ in range(60):
        time.sleep(2)
        m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", open(log_path, encoding="utf-8", errors="ignore").read())
        if m:
            return proc, m.group(0)
    return proc, None


def router_models():
    key = os.environ.get("JEAN_API_KEY", "")
    req = urllib.request.Request(f"http://127.0.0.1:{ROUTER_PORT}/v1/models", headers={"Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            j = json.loads(r.read())
        return [m["id"] for m in j.get("data", [])], j.get("jean", {}).get("unavailable", [])
    except Exception:
        return [], []


SESSION_KEY = False  # True si la clave se generó para esta sesión (no hay secreto)


def banner(url, ready):
    print("\n" + "=" * 72, flush=True)
    print(f"  URL para JeanCode :  {url}/v1", flush=True)
    if SESSION_KEY:
        print(f"  Clave             :  {os.environ['JEAN_API_KEY']}", flush=True)
        print("                       (solo para esta sesión; para una fija, añade el secreto JEAN_API_KEY)", flush=True)
    else:
        print("  Clave             :  tu JEAN_API_KEY (la de los Secrets de Kaggle)", flush=True)
    print(f"  Modelos listos    :  {', '.join(ready) if ready else '(cargando...)'}", flush=True)
    print("=" * 72 + "\n", flush=True)


# ------------------------------------------------------------------ main
def main():
    global SESSION_KEY
    if not os.environ.get("JEAN_API_KEY"):
        os.environ["JEAN_API_KEY"] = "jean-" + secrets.token_urlsafe(24)
        SESSION_KEY = True
        say("sin secreto JEAN_API_KEY: uso una clave nueva solo para esta sesión (la verás junto a la URL)")
    gpus = count_gpus()
    say(f"GPU detectadas: {gpus}" + ("" if gpus else " (sin GPU: Settings → Accelerator → GPU T4 x2 para ir mucho más rápido)"))
    plan = plan_slots(parse_models(os.environ.get("JEAN_MODELS")), gpus)
    ctx = int(os.environ.get("JEAN_CTX", "32768"))
    binary = install_llama(gpus)
    cf = install_cloudflared()
    for s in plan:
        if s["kind"] != "jean":
            s["custom_file"] = prepare_custom(s)
    procs = {s["port"]: start_model(s, binary, ctx) for s in plan}
    for s in plan:
        say(f"{s['alias']} → puerto {s['port']}" + (f", GPU {s['gpu']}" if s["gpu"] else ", CPU"))
    router = start_router(plan, binary, gpus)
    tunnel, url = start_tunnel(cf)
    if not url:
        say("no se pudo abrir el túnel de Cloudflare: ¿está activado Internet en Settings?")
        return 1
    say("los modelos tardan 2-5 minutos en descargarse y cargar la primera vez")
    banner(url, [])
    max_h = float(os.environ.get("JEAN_MAX_HOURS", "11.75"))  # Kaggle corta la sesión a las 12 h
    t0, last_ready, warned = time.time(), None, False
    while time.time() - t0 < max_h * 3600:
        time.sleep(60)
        for s in plan:  # un modelo caído se relanza (serve.sh deja el motivo al router)
            if procs[s["port"]].poll() is not None:
                say(f"{s['alias']} se detuvo; lo relanzo (detalle en {WORK}/serve-{s['port']}.log)")
                procs[s["port"]] = start_model(s, binary, ctx)
        if router.poll() is not None:
            say("router caído; lo relanzo")
            router = start_router(plan, binary, gpus)
        if tunnel.poll() is not None:
            tunnel, url = start_tunnel(cf)
            say("el túnel se reinició: LA URL CAMBIÓ")
            banner(url, last_ready or [])
        ready, down = router_models()
        if ready != last_ready:
            last_ready = ready
            banner(url, ready)
            for d in down:
                say(f"{d.get('slot')}: {d.get('reason')}")
        left = max_h * 3600 - (time.time() - t0)
        if left < 1800 and not warned:
            warned = True
            say("quedan 30 minutos de sesión: cuando termine, vuelve a pulsar Run All (la URL cambiará)")
    say("sesión terminada. Para seguir, vuelve a pulsar Run All.")
    for p in list(procs.values()) + [router, tunnel]:
        try:
            os.killpg(p.pid, signal.SIGTERM)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
