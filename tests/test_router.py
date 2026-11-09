"""Pruebas del router de Jean-API-Generator: logica pura y extremo a extremo con llama-servers falsos.

  python tests/test_router.py
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "control"))
import router  # noqa: E402

KEY = "test-key-0123456789"


class Resolve(unittest.TestCase):
    ready = {"jean-grey": 8888, "jean-marvel": 8889}

    def test_auto_prefers_grey(self):
        self.assertEqual(router.resolve("auto", self.ready), ("jean-grey", 8888))
        self.assertEqual(router.resolve(None, self.ready), ("jean-grey", 8888))

    def test_exact_and_case(self):
        self.assertEqual(router.resolve("JEAN-MARVEL", self.ready), ("jean-marvel", 8889))

    def test_partial_unique(self):
        self.assertEqual(router.resolve("fenix", {"jean-fenix-lite": 8890}), ("jean-fenix-lite", 8890))

    def test_ambiguous(self):
        with self.assertRaises(router.RouteError) as c:
            router.resolve("jean", self.ready)
        self.assertEqual(c.exception.status, 400)

    def test_known_but_down_is_503_with_alternatives(self):
        with self.assertRaises(router.RouteError) as c:
            router.resolve("jean-fenix", self.ready)
        self.assertEqual(c.exception.status, 503)
        self.assertEqual(c.exception.available, ["jean-grey", "jean-marvel"])

    def test_unknown_is_404(self):
        with self.assertRaises(router.RouteError) as c:
            router.resolve("gpt-4o", self.ready)
        self.assertEqual(c.exception.status, 404)

    def test_nothing_ready(self):
        with self.assertRaises(router.RouteError) as c:
            router.resolve("auto", {})
        self.assertEqual(c.exception.status, 503)

    def test_rewrite(self):
        with self.assertRaises(router.RouteError):
            router.rewrite_model(b"{nope", "x")
        self.assertEqual(json.loads(router.rewrite_model(b'{"model":"auto","a":1}', "jean-grey")[1]),
                         {"model": "jean-grey", "a": 1})


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def fake_llama(alias, loading=False):
    """llama-server falso: /health, /v1/models y /v1/chat/completions en streaming SSE."""
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def send_json(self, code, obj):
            b = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)

        def do_GET(self):
            if self.path == "/health":
                return self.send_json(503 if loading else 200, {"status": "loading" if loading else "ok"})
            if self.path == "/props":
                return self.send_json(200, {"default_generation_settings": {"n_ctx": 131072}})
            if self.headers.get("Authorization") != f"Bearer {KEY}":
                return self.send_json(401, {"error": "bad key"})
            self.send_json(200, {"data": [{"id": alias}]})

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            if self.headers.get("Authorization") != f"Bearer {KEY}":
                return self.send_json(401, {"error": "bad key"})
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            for word in (f"soy {body['model']}", " fin"):
                self.wfile.write(("data: " + json.dumps({"choices": [{"delta": {"content": word}}]}) + "\n\n").encode())
                self.wfile.flush()
                time.sleep(0.05)
            self.wfile.write(b"data: [DONE]\n\n")

    port = free_port()
    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return port, srv


class EndToEnd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.grey, cls.s1 = fake_llama("jean-grey")
        cls.marvel, cls.s2 = fake_llama("jean-marvel", loading=True)
        cls.dead = free_port()
        cls.port = free_port()
        env = dict(os.environ, JEAN_API_KEY=KEY, JEAN_CONTROL_PORT=str(cls.port),
                   JEAN_SLOTS=f"{cls.grey}:grey,{cls.marvel}:marvel,{cls.dead}:fenix")
        cls.proc = subprocess.Popen([sys.executable, os.path.join(ROOT, "control", "control_server.py")],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(80):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{cls.port}/health", timeout=1)
                break
            except Exception:
                time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(5)
        cls.s1.shutdown()
        cls.s2.shutdown()

    def call(self, path, body=None, key=KEY):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}", method="POST" if body is not None else "GET",
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return r.status, dict(r.headers), r.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers), e.read().decode()

    def test_health_is_public_and_minimal(self):
        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/health") as r:
            self.assertEqual(json.loads(r.read()), {"ok": True, "ready": 1})

    def test_key_required(self):
        self.assertEqual(self.call("/v1/models", key="mala")[0], 401)
        self.assertEqual(self.call("/v1/chat/completions", {"model": "auto"}, key="mala")[0], 401)

    def test_models_lists_ready_and_explains_the_rest(self):
        code, _, body = self.call("/v1/models")
        j = json.loads(body)
        self.assertEqual(code, 200)
        self.assertEqual([m["id"] for m in j["data"]], ["jean-grey"])
        self.assertEqual(j["data"][0]["jean"]["context_length"], 131072)
        reasons = {u["slot"]: u["reason"] for u in j["jean"]["unavailable"]}
        self.assertEqual(reasons["jean-marvel"], "cargando el modelo")
        self.assertEqual(reasons["jean-fenix"], "apagado")

    def test_streams_through_with_resolved_model(self):
        code, headers, body = self.call("/v1/chat/completions", {"model": "auto", "stream": True,
                                                                 "messages": [{"role": "user", "content": "hola"}]})
        self.assertEqual(code, 200)
        self.assertEqual(headers.get("X-Jean-Model"), "jean-grey")
        self.assertIn("soy jean-grey", body)
        self.assertIn("[DONE]", body)

    def test_unavailable_model_is_clear(self):
        code, _, body = self.call("/v1/chat/completions", {"model": "jean-marvel", "messages": []})
        self.assertEqual(code, 503)
        err = json.loads(body)["error"]
        self.assertEqual(err["available"], ["jean-grey"])
        self.assertIn("no esta disponible", err["message"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
