"""Router OpenAI-compatible de Jean-API-Generator.

Una sola URL (el puerto de control, 8899) para todos los modelos del Codespace:

  GET  /v1/models                 modelos listos de todos los puertos (+ los que no lo estan, con motivo)
  POST /v1/chat/completions       se envia al puerto que sirve el "model" pedido
  POST /v1/completions | /v1/embeddings   igual

"model": "auto" (o vacio) elige el primer modelo listo en el orden grey > marvel > fenix > otros.
Un nombre parcial unico tambien vale ("jean-fenix" encuentra "jean-fenix-lite").
Nunca cambia de modelo en silencio: si el pedido no esta disponible, responde 503 con la lista
de modelos que si lo estan, y el cliente decide.

Solo biblioteca estandar. La logica de eleccion (resolve) es pura y se prueba en tests/test_router.py.
"""
import json
import threading
import time
import urllib.error
import urllib.request

PREFERENCE = ("grey", "marvel", "fenix")
PROXY_PATHS = ("/v1/chat/completions", "/v1/completions", "/v1/embeddings")
MAX_BODY = 16 * 2**20          # 128k de contexto en JSON cabe de sobra
READ_TIMEOUT = 900             # Fenix en CPU puede tardar minutos entre trozos


class RouteError(Exception):
    """Error con forma de error de OpenAI ({"error": {...}}) para que cualquier cliente lo muestre."""

    def __init__(self, status, message, kind="jean_router_error", available=None):
        super().__init__(message)
        self.status, self.message, self.kind, self.available = status, message, kind, available or []

    def body(self):
        err = {"message": self.message, "type": self.kind}
        if self.available:
            err["available"] = self.available
        return {"error": err}


def rank(model_id):
    """Orden de preferencia para "auto": primero los modelos Jean conocidos."""
    low = model_id.lower()
    for i, name in enumerate(PREFERENCE):
        if name in low:
            return i
    return len(PREFERENCE)


def resolve(requested, ready):
    """Elige el puerto para un modelo.

    requested: nombre pedido por el cliente ("auto", "" o None = automatico).
    ready: {model_id: port} de los modelos que responden ahora.
    Devuelve (model_id, port). Lanza RouteError si no hay a donde enviarlo.
    """
    available = sorted(ready, key=lambda m: (rank(m), m))
    if not available:
        raise RouteError(503, "Ningun modelo esta listo todavia. Si el Codespace acaba de despertar, "
                              "espera 2-4 minutos.", "jean_unavailable")
    want = (requested or "auto").strip()
    if want.lower() == "auto":
        return available[0], ready[available[0]]
    for m in available:                       # exacto (sin distinguir mayusculas)
        if m.lower() == want.lower():
            return m, ready[m]
    partial = [m for m in available if want.lower() in m.lower()]
    if len(partial) == 1:
        return partial[0], ready[partial[0]]
    if len(partial) > 1:
        raise RouteError(400, f'"{want}" coincide con varios modelos: {", ".join(partial)}. '
                              "Usa el nombre completo.", "jean_ambiguous_model", partial)
    raise RouteError(503 if rank(want) < len(PREFERENCE) else 404,
                     f'El modelo "{want}" no esta disponible ahora. Disponibles: {", ".join(available)}.',
                     "jean_model_unavailable", available)


class SlotTable:
    """Que modelo sirve cada puerto, con cache corta para no consultar en cada peticion."""

    def __init__(self, slots, key, ttl=5.0, probe_timeout=4):
        self.slots, self.key, self.ttl, self.probe_timeout = slots, key, ttl, probe_timeout
        self._at, self._ready, self._down, self._ctx = 0.0, {}, {}, {}
        self._lock = threading.Lock()

    def _probe(self, port):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=self.probe_timeout) as r:
                if r.status != 200:
                    return None, "cargando"
        except urllib.error.HTTPError as e:
            return None, "cargando el modelo" if e.code == 503 else f"health {e.code}"
        except Exception:
            return None, "apagado"
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/models",
                                         headers={"Authorization": f"Bearer {self.key}"})
            with urllib.request.urlopen(req, timeout=self.probe_timeout) as r:
                ids = [m.get("id") for m in json.loads(r.read()).get("data", []) if m.get("id")]
            return ids, None
        except Exception as e:
            return None, f"no lista modelos ({type(e).__name__})"

    def _context(self, port):
        """Contexto CONFIGURADO del llama-server (-c), de /props. None si no lo informa."""
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{port}/props", headers={"Authorization": f"Bearer {self.key}"})
            with urllib.request.urlopen(req, timeout=self.probe_timeout) as r:
                j = json.loads(r.read())
            n = (j.get("default_generation_settings") or {}).get("n_ctx") or j.get("n_ctx")
            return int(n) if n else None
        except Exception:
            return None

    def snapshot(self, force=False):
        """Devuelve ({model: port}, {port: motivo}) de los puertos conocidos."""
        with self._lock:
            if force or time.time() - self._at > self.ttl:
                ready, down, ctx = {}, {}, {}
                for port in self.slots:
                    ids, why = self._probe(port)
                    if ids:
                        n = self._context(port)
                        for m in ids:
                            ready.setdefault(m, port)
                            if n:
                                ctx.setdefault(m, n)
                    else:
                        down[port] = why
                self._ready, self._down, self._ctx, self._at = ready, down, ctx, time.time()
            return dict(self._ready), dict(self._down)

    def contexts(self):
        with self._lock:
            return dict(self._ctx)

    def invalidate(self):
        with self._lock:
            self._at = 0.0


def models_payload(ready, down, slot_names, notes=None, contexts=None):
    """Cuerpo de /v1/models: formato OpenAI, mas un campo jean con el estado de cada puerto
    y el contexto configurado (context_length) cuando llama-server lo informa."""
    notes, contexts = notes or {}, contexts or {}

    def info(m, p):
        j = {"port": p, "state": "ready"}
        if contexts.get(m):
            j["context_length"] = contexts[m]
        return j
    data = [{"id": m, "object": "model", "owned_by": "jean-api-generator", "jean": info(m, p)}
            for m, p in sorted(ready.items(), key=lambda kv: (rank(kv[0]), kv[0]))]
    unavailable = [{"slot": slot_names.get(p, str(p)), "port": p, "reason": notes.get(p) or why}
                   for p, why in sorted(down.items())]
    return {"object": "list", "data": data, "jean": {"router": True, "unavailable": unavailable}}


def rewrite_model(body_bytes, model_id):
    """Pone el modelo resuelto en el cuerpo JSON (para "auto" y nombres parciales)."""
    try:
        payload = json.loads(body_bytes or b"{}")
    except ValueError:
        raise RouteError(400, "El cuerpo no es JSON valido.", "invalid_request_error")
    if not isinstance(payload, dict):
        raise RouteError(400, "El cuerpo debe ser un objeto JSON.", "invalid_request_error")
    requested = payload.get("model")
    payload["model"] = model_id
    return requested, json.dumps(payload).encode()


def requested_model(body_bytes):
    try:
        payload = json.loads(body_bytes or b"{}")
        return payload.get("model") if isinstance(payload, dict) else None
    except ValueError:
        raise RouteError(400, "El cuerpo no es JSON valido.", "invalid_request_error")


def forward(handler, port, path, body, key):
    """Envia la peticion al llama-server del puerto y copia la respuesta trozo a trozo (streaming)."""
    req = urllib.request.Request(f"http://127.0.0.1:{port}{path}", data=body, method="POST",
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                                          "Accept": handler.headers.get("Accept", "*/*")})
    try:
        upstream = urllib.request.urlopen(req, timeout=READ_TIMEOUT)
    except urllib.error.HTTPError as e:
        upstream = e                              # errores del modelo (400, 503 cargando...): se pasan tal cual
    except Exception as e:
        raise RouteError(503, f"El modelo del puerto {port} dejo de responder ({type(e).__name__}).",
                         "jean_unavailable")
    status = getattr(upstream, "status", None) or upstream.code
    handler.send_response(status)
    handler.cors()
    handler.send_header("Content-Type", upstream.headers.get("Content-Type", "application/json"))
    handler.send_header("Cache-Control", "no-cache")
    handler.send_header("X-Jean-Port", str(port))
    handler.send_header("Connection", "close")
    handler.close_connection = True
    for name, value in getattr(handler, "extra_headers", {}).items():
        handler.send_header(name, value)
    handler.end_headers()
    try:
        while True:
            chunk = upstream.read1(65536) if hasattr(upstream, "read1") else upstream.read(65536)
            if not chunk:
                break
            handler.wfile.write(chunk)
            handler.wfile.flush()
    except (BrokenPipeError, ConnectionResetError):
        pass                                      # el cliente cancelo (boton detener)
    finally:
        upstream.close()


# ---------------------------------------------------------------- relay (CORS) para clientes web
# Muchas APIs (NVIDIA NIM, SambaNova, DeepSeek, Mistral...) no aceptan llamadas desde una pagina web
# (CORS). El cliente web de JeanCode puede enviarlas por TU Codespace: /relay/<host>/<ruta>.
# Solo a hosts de esta lista (no es un proxy abierto), solo https, sin seguir redirecciones, y
# exige X-Jean-Key (tu JEAN_API_KEY). La clave del proveedor (Authorization) pasa sin tocarse y
# nunca se registra.
RELAY_HOSTS = frozenset("""
api.openai.com api.anthropic.com generativelanguage.googleapis.com openrouter.ai api.groq.com
router.huggingface.co api.deepseek.com api.mistral.ai api.x.ai api.together.xyz api.fireworks.ai
api.cerebras.ai integrate.api.nvidia.com api.sambanova.ai api.deepinfra.com api.hyperbolic.xyz
api.novita.ai api.tokenfactory.nebius.com api.studio.nebius.com llm.chutes.ai api.siliconflow.com
api.inference.net api.moonshot.ai api.z.ai dashscope-intl.aliyuncs.com api.minimax.io api.cohere.ai
api.scaleway.ai openai.inference.de-txl.ionos.com
""".split())
RELAY_FORWARD_HEADERS = ("authorization", "content-type", "accept", "x-title", "http-referer",
                         "anthropic-version", "x-api-key")
_HOST_RE = __import__("re").compile(r"^[a-z0-9.-]+(:\d{1,5})?$")


def relay_hosts(extra=""):
    """Lista permitida + JEAN_RELAY_HOSTS (separados por comas) para APIs propias."""
    return RELAY_HOSTS | {h.strip().lower() for h in (extra or "").split(",") if h.strip()}


def relay_target(path, hosts, local_http=False):
    """/relay/<host>/<ruta>?q -> https://<host>/<ruta>?q. Lanza RouteError si no esta permitido.
    local_http solo para pruebas: permite http a 127.0.0.1."""
    rest = path[len("/relay/"):] if path.startswith("/relay/") else ""
    host, slash, tail = rest.partition("/")
    host = host.lower()
    if not host or not slash or not _HOST_RE.match(host):
        raise RouteError(400, "Ruta de relay invalida: usa /relay/<host>/<ruta>.", "jean_relay_error")
    if host not in hosts:
        raise RouteError(403, f"El relay no reenvia a {host}. Anadelo a JEAN_RELAY_HOSTS si es tuyo.", "jean_relay_forbidden")
    scheme = "http" if local_http and host.startswith("127.0.0.1:") else "https"
    if ":" in host and scheme == "https" and not host.endswith(":443"):
        raise RouteError(403, "El relay solo usa el puerto 443.", "jean_relay_forbidden")
    return f"{scheme}://{host}/{tail}"


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None                              # una redireccion podria llevar la clave a otro host


_OPENER = urllib.request.build_opener(_NoRedirect)


def relay(handler, method, url, body):
    """Reenvia la peticion del cliente al proveedor y copia la respuesta trozo a trozo."""
    headers = {k: v for k, v in handler.headers.items() if k.lower() in RELAY_FORWARD_HEADERS}
    headers.setdefault("User-Agent", "Jean-API-Generator relay")
    req = urllib.request.Request(url, data=body if method == "POST" else None, method=method, headers=headers)
    try:
        upstream = _OPENER.open(req, timeout=READ_TIMEOUT)
    except urllib.error.HTTPError as e:
        upstream = e                             # 401/429/... del proveedor: se pasan tal cual
    except Exception as e:
        raise RouteError(502, f"No se pudo contactar con el proveedor ({type(e).__name__}).", "jean_relay_error")
    status = getattr(upstream, "status", None) or upstream.code
    handler.send_response(status)
    handler.cors()
    handler.send_header("Content-Type", upstream.headers.get("Content-Type", "application/json"))
    handler.send_header("Cache-Control", "no-cache")
    handler.send_header("Connection", "close")
    handler.close_connection = True
    handler.end_headers()
    try:
        while True:
            chunk = upstream.read1(65536) if hasattr(upstream, "read1") else upstream.read(65536)
            if not chunk:
                break
            handler.wfile.write(chunk)
            handler.wfile.flush()
    except (BrokenPipeError, ConnectionResetError):
        pass
    finally:
        upstream.close()
