#!/usr/bin/env bash
# test_ctx.sh — prueba de contexto 128k con KV q8_0 en grey y marvel.
# Resultados en /tmp/test_ctx.out
exec > /tmp/test_ctx.out 2>&1

pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1

BIN=$(find "$HOME/llama" -name llama-server -type f | head -1)
echo "bin: $BIN"

launch() { # $1=archivo $2=puerto $3=alias
  nohup "$BIN" -m "$HOME/gguf/$1" --host 0.0.0.0 --port "$2" --alias "$3" \
    -c 131072 -ctk q8_0 -ctv q8_0 --threads 4 --temp 0.2 --top-p 0.9 \
    --api-key "$JEAN_API_KEY" > "/tmp/ctx-$2.log" 2>&1 &
  echo "lanzando $3 (puerto $2) ..."
}

launch jean-grey-v0.7.Q4_K_M.gguf 8888 jean-grey
sleep 55
grep -E 'KV self size|n_ctx_per_seq|error|failed' /tmp/ctx-8888.log | head -5
free -m | awk '/Mem:/'

launch jean-marvel-v0.7.Q4_K_M.gguf 8889 jean-marvel
sleep 110
grep -E 'KV self size|n_ctx_per_seq|error|failed' /tmp/ctx-8889.log | head -5
free -m | awk '/Mem:/'

echo "--- servidores vivos ---"
pgrep -ax llama-server | cut -c1-120

echo "--- test inferencia grey ---"
code=$(curl -s -o /tmp/g.json -w '%{http_code}' -m 240 \
  -H "Authorization: Bearer $JEAN_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"Responde solo: ctx-ok"}],"max_tokens":30}' \
  http://127.0.0.1:8888/v1/chat/completions 2>/dev/null || echo 000)
echo "grey http=$code -> $(python3 -c 'import json;print(json.load(open("/tmp/g.json"))["choices"][0]["message"]["content"])' 2>/dev/null || echo '?')"

echo "--- test inferencia marvel ---"
code=$(curl -s -o /tmp/m.json -w '%{http_code}' -m 240 \
  -H "Authorization: Bearer $JEAN_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"jean-marvel","messages":[{"role":"user","content":"Responde solo: ctx-ok"}],"max_tokens":30}' \
  http://127.0.0.1:8889/v1/chat/completions 2>/dev/null || echo 000)
echo "marvel http=$code -> $(python3 -c 'import json;print(json.load(open("/tmp/m.json"))["choices"][0]["message"]["content"])' 2>/dev/null || echo '?')"

echo "--- RAM final ---"
free -m | awk '/Mem:/'
echo "FIN-TEST"
