#!/usr/bin/env bash
# Arranque dentro de un Space de Hugging Face (lo llama space/Dockerfile).
# Cada modelo corre en un bucle que lo relanza si se cae; el router (control/control_server.py)
# atiende en :7860, el único puerto que Hugging Face publica, y reparte a cada modelo.
set -u
cd "$(dirname "$0")/.."

if [ -z "${JEAN_API_KEY:-}" ]; then
  echo "[space] Falta el secreto JEAN_API_KEY."
  echo "[space] Añádelo en Settings → Variables and secrets → New secret y reinicia el Space."
  exit 1
fi

keep() {  # keep <puerto> <modelo>
  while true; do
    PORT="$1" bash serve.sh "$2" 2>&1 | sed -u "s/^/[$2] /"
    echo "[space] $2 se detuvo; lo relanzo en 15 s"
    sleep 15
  done
}

for slot in ${JEAN_SLOTS//,/ }; do
  keep "${slot%%:*}" "${slot#*:}" &
done

echo "[space] router en :${JEAN_CONTROL_PORT:-7860} (los modelos tardan 2-4 minutos en cargar)"
exec python3 control/control_server.py
