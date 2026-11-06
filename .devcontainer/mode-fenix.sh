#!/usr/bin/env bash
# mode-fenix.sh — cambia el codespace al modo FENIX-LITE (persistente).
set -uo pipefail
ROOT="${JEAN_REPO_DIR:-/workspaces/jean-api}"
echo fenix > "$ROOT/.jean-mode"
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
pkill curl 2>/dev/null
sleep 1
setsid nohup bash "$ROOT/.devcontainer/autostart.sh" > /tmp/autostart-fenix.log 2>&1 < /dev/null &
echo "[mode-fenix] modo fenix-lite activado en :8890 (persiste entre reinicios)"
