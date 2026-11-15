#!/usr/bin/env bash
# e2e_launch.sh — prueba real de launch.py en esta máquina (Linux x86_64 o WSL), sin túnel.
# Sirve un GGUF pequeño (por defecto Qwen3-0.6B, ~400 MB), espera a que el router lo vea y le pide
# una respuesta de verdad. La clave se genera aquí y nunca se imprime.
#   bash tests/e2e_launch.sh                      (JEAN_E2E_MODEL=hf:... para otro modelo)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODEL="${JEAN_E2E_MODEL:-hf:unsloth/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q4_K_M.gguf}"
export JEAN_API_KEY="e2e-$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
export JEAN_MODELS="$MODEL" JEAN_TUNNEL=0 JEAN_CTX=4096 JEAN_MAX_HOURS=0.5
LOG="$(mktemp)"
python3 "$REPO/launch.py" > "$LOG" 2>&1 &
PID=$!
cleanup() { kill -INT "$PID" 2>/dev/null; sleep 3; kill "$PID" 2>/dev/null; pkill -f "$REPO/serve.sh" 2>/dev/null; pkill -f control_server.py 2>/dev/null; }
trap cleanup EXIT
fail() { echo "FAIL  $1"; sed -e "s/$JEAN_API_KEY/<clave>/g" "$LOG" | tail -25; exit 1; }

PORT=8899
for i in $(seq 1 180); do                       # hasta 15 min (descargas)
  sleep 5
  kill -0 "$PID" 2>/dev/null || fail "launch.py terminó antes de tiempo"
  PORT=$(grep -o 'http://127.0.0.1:[0-9]*' "$LOG" | head -1 | cut -d: -f3); PORT=${PORT:-8899}
  READY=$(curl -s "http://127.0.0.1:$PORT/health" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("ready",0))' 2>/dev/null)
  [ "${READY:-0}" -ge 1 ] && break
done
[ "${READY:-0}" -ge 1 ] || fail "ningún modelo listo en 15 minutos"
echo "PASS  /health: $READY modelo(s) listo(s) en el router :$PORT"

CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/v1/models")
[ "$CODE" = 401 ] && echo "PASS  sin clave: 401" || fail "sin clave devolvió $CODE"

OUT=$(curl -s "http://127.0.0.1:$PORT/v1/chat/completions" -H "Authorization: Bearer $JEAN_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"auto","max_tokens":40,"messages":[{"role":"user","content":"Responde solo: hola"}]}')
echo "$OUT" | python3 -c 'import json,sys;j=json.load(sys.stdin);t=j["choices"][0]["message"];print("PASS  respuesta del modelo:", repr((t.get("content") or t.get("reasoning_content") or "")[:80]))' \
  || fail "el chat no respondió: $(echo "$OUT" | head -c 300)"
grep -q "$JEAN_API_KEY" "$LOG" && echo "nota: la clave de esta prueba aparece en el log local (es la de la sesión, se muestra una vez por diseño)"
echo "OK"
