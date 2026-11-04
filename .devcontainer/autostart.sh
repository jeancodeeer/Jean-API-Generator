#!/usr/bin/env bash
# postStartCommand: arranca la API sola en cada inicio del Codespace.
# Requiere los secrets HF_TOKEN y JEAN_API_KEY (si faltan, no hace nada).
# Modelos: grey -> :8888 (primario), marvel -> :8889 (secundario).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

if [ -z "${JEAN_API_KEY:-}" ]; then
  echo "[autostart] falta JEAN_API_KEY - no arranco"
  exit 0
fi

start_model() {
  local model="$1" port="$2"
  if pgrep -f "llama-server.*--port ${port}" >/dev/null 2>&1; then
    echo "[autostart] $model ya corriendo en :$port"
    return 0
  fi
  echo "[autostart] lanzando $model en :$port"
  PORT="$port" JEAN_SOURCE="${JEAN_SOURCE:-hf}" \
    nohup bash "$ROOT/serve.sh" "$model" > "/tmp/serve-$model.log" 2>&1 &
}

start_model grey 8888
start_model marvel 8889
echo "[autostart] listo"
