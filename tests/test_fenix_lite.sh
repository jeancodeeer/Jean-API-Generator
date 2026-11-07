#!/usr/bin/env bash
# test_fenix_lite.sh — prueba completa de Fenix-lite en el codespace de 16 GB.
# Para grey/marvel, lanza fenix-lite en :8890 y testea. Resultados en
# /tmp/fenix_lite.out
exec > /tmp/fenix_lite.out 2>&1

pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1

REPO_DIR=$(dirname "$(find "$HOME" -maxdepth 6 -name serve.sh 2>/dev/null | head -1)")
echo "repo: $REPO_DIR"
cd "$REPO_DIR" || exit 1

PORT=8890 FENIX_FILE="${FENIX_FILE:-jean-fenix-v0.7.lite-IQ4_XS.gguf}" \
  FENIX_ALIAS="${FENIX_ALIAS:-jean-fenix-lite}" FENIX_CTX="${FENIX_CTX:-4096}" \
  nohup bash serve.sh fenix > /tmp/serve-fenix.log 2>&1 &

echo "fenix-lite lanzando (descarga ~13.6 GiB la primera vez + carga) ..."
ok=0
for i in $(seq 1 200); do
  sleep 6
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    -H "Authorization: Bearer $JEAN_API_KEY" \
    "http://127.0.0.1:8890/v1/models" 2>/dev/null || true)
  if [ "$code" = "200" ]; then ok=1; break; fi
done
echo "models: http=$code tras $((i*6))s (ok=$ok)"
free -m | awk '/Mem:/'

body='{"model":"jean-fenix-lite","messages":[{"role":"user","content":"Responde solo: fenix-lite-ok"}],"max_tokens":40}'
code2=$(curl -s -o /tmp/f.json -w '%{http_code}' -m 300 \
  -H "Authorization: Bearer $JEAN_API_KEY" -H 'Content-Type: application/json' \
  -d "$body" http://127.0.0.1:8890/v1/chat/completions 2>/dev/null || echo 000)
echo "inferencia: $code2 -> $(python3 -c 'import json;print(json.load(open("/tmp/f.json"))["choices"][0]["message"]["content"])' 2>/dev/null || echo '?')"

echo "--- RAM final ---"
free -m | awk '/Mem:/'
echo "--- cola de errores si los hay ---"
grep -iE 'error|failed|oom|killed' /tmp/serve-fenix.log | tail -5
echo FIN-FENIX-LITE
