#!/usr/bin/env bash
# mode-standard.sh — vuelve al modo estandar del codespace (grey + marvel).
set -uo pipefail
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1
ROOT="${JEAN_REPO_DIR:-/workspaces/jean-api}"
[ -f "$ROOT/.devcontainer/autostart.sh" ] || ROOT=$(dirname "$(dirname "$(find / -maxdepth 6 -name autostart.sh 2>/dev/null | head -1)")")
[ -f "$ROOT/.devcontainer/autostart.sh" ] || { echo "[mode-standard] no encontre autostart"; exit 1; }

setsid nohup bash "$ROOT/.devcontainer/autostart.sh" > /tmp/autostart-manual.log 2>&1 < /dev/null &
echo "[mode-standard] grey + marvel de vuelta (autostart)"
