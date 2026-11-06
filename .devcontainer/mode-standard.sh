#!/usr/bin/env bash
# mode-standard.sh — vuelve al modo estandar del codespace (grey + marvel).
set -uo pipefail
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
sleep 1
DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$DIR")
nohup bash "$ROOT/.devcontainer/autostart.sh" > /tmp/autostart-manual.log 2>&1 &
echo "[mode-standard] grey + marvel de vuelta (autostart)"
