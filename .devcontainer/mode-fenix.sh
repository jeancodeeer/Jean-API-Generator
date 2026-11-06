#!/usr/bin/env bash
# mode-fenix.sh — cambia el codespace al modo FENIX-LITE (para grey/marvel).
# Uso (dentro del codespace): bash .devcontainer/mode-fenix.sh
# Vars opcionales: FENIX_FILE, FENIX_ALIAS, FENIX_CTX
set -uo pipefail
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1
DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$DIR")

PORT=8890 FENIX_FILE="${FENIX_FILE:-jean-fenix-v0.7.lite-IQ4_XS.gguf}" \
  FENIX_ALIAS="${FENIX_ALIAS:-jean-fenix-lite}" FENIX_CTX="${FENIX_CTX:-4096}" \
  nohup bash "$ROOT/serve.sh" fenix > /tmp/serve-fenix.log 2>&1 &

echo "[mode-fenix] fenix-lite lanzando en :8890 (la primera vez descarga ~13.6 GiB)"
echo "[mode-fenix] progreso: tail -f /tmp/serve-fenix.log"
