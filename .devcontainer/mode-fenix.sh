#!/usr/bin/env bash
# mode-fenix.sh — cambia el codespace al modo FENIX-LITE (para grey/marvel).
# Uso (dentro del codespace): bash .devcontainer/mode-fenix.sh
# Vars opcionales: FENIX_FILE, FENIX_ALIAS, FENIX_CTX
set -uo pipefail
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1
ROOT="${JEAN_REPO_DIR:-/workspaces/jean-api}"
[ -f "$ROOT/serve.sh" ] || ROOT=$(dirname "$(find / -maxdepth 5 -name serve.sh 2>/dev/null | head -1)")
[ -f "$ROOT/serve.sh" ] || { echo "[mode-fenix] no encontre serve.sh"; exit 1; }

PORT=8890 FENIX_FILE="${FENIX_FILE:-jean-fenix-v0.7.lite-IQ4_XS.gguf}" \
  FENIX_ALIAS="${FENIX_ALIAS:-jean-fenix-lite}" FENIX_CTX="${FENIX_CTX:-4096}" \
  setsid nohup bash "$ROOT/serve.sh" fenix > /tmp/serve-fenix.log 2>&1 < /dev/null &

echo "[mode-fenix] fenix-lite lanzando en :8890 (la primera vez descarga ~14 GiB)"
echo "[mode-fenix] progreso: tail -f /tmp/serve-fenix.log"
