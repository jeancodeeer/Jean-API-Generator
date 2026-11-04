#!/usr/bin/env bash
# Watchdog: cada 60s comprueba que cada modelo siga respondiendo y lo relanza.
# Se lanza en segundo plano desde autostart.sh (setsid, sobrevive al cierre de sesion).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

check() {
  local model="$1" port="$2"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 6 \
    -H "Authorization: Bearer ${JEAN_API_KEY:-}" \
    "http://localhost:$port/v1/models" 2>/dev/null || true)
  # 503 = cargando el modelo: normal, no relanzar
  if [ "$code" = "200" ] || [ "$code" = "503" ]; then
    return 0
  fi
  echo "[watchdog $(date -u +%FT%TZ)] $model (:${port}) no responde (code=${code:-none}); relanzando"
  pkill -f "llama-server.*--port ${port}" 2>/dev/null || true
  sleep 2
  PORT="$port" JEAN_SOURCE="${JEAN_SOURCE:-hf}" \
    setsid nohup bash "$ROOT/serve.sh" "$model" >> "/tmp/serve-$model.log" 2>&1 &
}

echo "[watchdog] arriba $(date -u +%FT%TZ)"
while true; do
  sleep 60
  check grey 8888
  MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  [ "$MEM_MB" -ge 14000 ] && check marvel 8889
done
