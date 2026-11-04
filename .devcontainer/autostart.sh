#!/usr/bin/env bash
# postStartCommand: arranca la API sola en cada inicio del Codespace.
# Requiere los secrets HF_TOKEN y JEAN_API_KEY (si faltan, no hace nada).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${HF_TOKEN:-}" ] || [ -z "${JEAN_API_KEY:-}" ]; then
  echo "[autostart] sin secrets HF_TOKEN/JEAN_API_KEY - no arranco"
  exit 0
fi
if pgrep -f "llama-server.*--port 8888" >/dev/null 2>&1; then
  echo "[autostart] ya corriendo"
  exit 0
fi
echo "[autostart] lanzando serve.sh ${JEAN_MODEL:-marvel}"
nohup bash "$HERE/../serve.sh" "${JEAN_MODEL:-marvel}" > /tmp/serve.log 2>&1 &
echo "[autostart] OK pid $!"
