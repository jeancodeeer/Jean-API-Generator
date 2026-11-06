#!/usr/bin/env bash
# mode-standard.sh — vuelve al modo estandar (grey + marvel), persistente.
set -uo pipefail
ROOT="${JEAN_REPO_DIR:-/workspaces/jean-api}"
rm -f "$ROOT/.jean-mode"
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
pkill curl 2>/dev/null
sleep 1
setsid nohup bash "$ROOT/.devcontainer/autostart.sh" > /tmp/autostart-standard.log 2>&1 < /dev/null &
echo "[mode-standard] modo grey + marvel activado (:8888 / :8889)"
