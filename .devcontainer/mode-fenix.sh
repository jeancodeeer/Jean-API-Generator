#!/usr/bin/env bash
# mode-fenix.sh — cambia el codespace al modo FENIX (persistente).
set -uo pipefail
# carpeta del repo: JEAN_REPO_DIR, la del script, o la de /workspaces que tenga serve.sh
# (jean-api.ps1 lo ejecuta con "curl | bash", donde $0 no es el script)
ROOT="${JEAN_REPO_DIR:-}"
if [ -z "$ROOT" ]; then
  for d in "$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" /workspaces/*; do
    [ -f "$d/serve.sh" ] && { ROOT="$d"; break; }
  done
fi
[ -n "$ROOT" ] || { echo "no encuentro el repo (serve.sh) en /workspaces" >&2; exit 1; }
echo fenix > "$ROOT/.jean-mode"
pkill -f watchdog.sh 2>/dev/null
pkill llama-server 2>/dev/null
pkill -f "curl.*huggingface.co" 2>/dev/null  # solo descargas de modelos
sleep 1
setsid nohup bash "$ROOT/.devcontainer/autostart.sh" > /tmp/autostart-fenix.log 2>&1 < /dev/null &
echo "[mode-fenix] modo fenix activado en :8890 (el GGUF que quepa en la RAM) (persiste entre reinicios)"
