#!/usr/bin/env bash
# Valida de punta a punta que un modelo se puede servir DESDE GitHub:
# baja las partes del release, las concatena, verifica sha256 y arranca
# llama-server contra el resultado. Uso: bash test_github_source.sh grey
set -uo pipefail
MODEL="${1:-grey}"
REPO="jeancodeeer/jean-api"
TAG="v0.7-models"
FILE="jean-${MODEL}-v0.7.Q4_K_M.gguf"
BASE="$(basename "$FILE" .gguf)"
DIR="/tmp/ghtest/$BASE"
rm -rf "$DIR"; mkdir -p "$DIR"

echo "[test] release $REPO@$TAG / $BASE"
python3 - "$REPO" "$TAG" "$BASE" "$DIR/$FILE" <<'PY'
import hashlib, json, os, subprocess, sys

repo, tag, base, out = sys.argv[1:5]
token = os.environ.get("GH_PAT", "")
hdr_json = ["-H", "Accept: application/vnd.github+json"]
hdr_bin = ["-H", "Accept: application/octet-stream"]
if token:
    auth = ["-H", f"Authorization: Bearer {token}"]
    hdr_json += auth
    hdr_bin += auth

def api_json(url):
    return json.loads(subprocess.check_output(["curl", "-fsSL", *hdr_json, url]))

rel = api_json(f"https://api.github.com/repos/{repo}/releases/tags/{tag}")
assets = {a["name"]: a for a in rel["assets"]}
man = assets.get(base + ".manifest.json")
if not man:
    sys.exit("[test] FALLO: no hay manifest en el release")
m = json.loads(subprocess.check_output(["curl", "-fsSL", *hdr_bin, man["url"]]))
print(f"[test] manifest: {len(m['parts'])} partes, {m['bytes']} bytes", flush=True)

h = hashlib.sha256()
with open(out, "wb") as g:
    for p in m["parts"]:
        a = assets.get(p["name"])
        if not a:
            sys.exit(f"[test] FALLO: falta el asset {p['name']}")
        print(f"[test]   bajando {p['name']} ({p['bytes']/2**30:.2f} GiB)", flush=True)
        subprocess.run(["curl", "-fsSL", "--retry", "3", *hdr_bin, a["url"]],
                       stdout=g, check=True)
with open(out, "rb") as f:
    for chunk in iter(lambda: f.read(8 << 20), b""):
        h.update(chunk)

got = h.hexdigest()
print(f"[test] sha256 {got}", flush=True)
if got != m["sha256"]:
    os.remove(out)
    sys.exit(f"[test] FALLO sha256: esperado {m['sha256']}")
print("[test] sha256 OK", flush=True)
PY
[ $? -eq 0 ] || exit 1

echo "[test] arrancando llama-server contra el GGUF bajado de GitHub ..."
BIN=$(find "$HOME/llama" -name llama-server -type f | head -1)
setsid nohup "$BIN" -m "$DIR/$FILE" --host 127.0.0.1 --port 8899 \
  --alias "test-$MODEL" -c 2048 --threads 4 > /tmp/ghtest-serve.log 2>&1 &
code=""
for i in $(seq 1 40); do
  sleep 3
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://127.0.0.1:8899/v1/models || true)
  [ "$code" = "200" ] && break
done
if [ "$code" != "200" ]; then
  echo "[test] FALLO: el server no respondio (code=$code)"; tail -5 /tmp/ghtest-serve.log
  pkill -f "llama-server.*--port 8899" 2>/dev/null || true
  exit 1
fi
echo "[test] server OK, probando inferencia ..."
curl -s -m 240 http://127.0.0.1:8899/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"test-$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Responde solo: desde-github\"}],\"max_tokens\":300}" \
  | python3 -c 'import json,sys
d=json.load(sys.stdin)
print("[test] respuesta:", repr(d["choices"][0]["message"]["content"]))'
pkill -f "llama-server.*--port 8899" 2>/dev/null || true
rm -rf "$DIR"
echo "[test] RESULTADO: $MODEL servible desde GitHub OK"
