#!/usr/bin/env bash
# postStartCommand: arranca la API sola en cada inicio del Codespace.
# Requiere JEAN_API_KEY. Fuente de modelos: HF (JEAN_SOURCE=hf, default).
# Si existe GH_PAT, publica un status en el repo para depurar sin SSH.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REPO="${JEAN_GH_REPO:-jeancodeeer/jean-api}"

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

# --- status para depurar sin SSH -------------------------------------------
publish_status() {
  [ -z "${GH_PAT:-}" ] && return 0
  local tmp; tmp=$(mktemp)
  {
    echo "# status $(date -u +%FT%TZ)"
    echo
    echo '## memoria'
    free -m || true
    echo
    echo '## procesos'
    pgrep -af llama-server || echo "(ninguno)"
    echo
    for f in /tmp/serve-*.log; do
      [ -f "$f" ] || continue
      echo "## $(basename "$f")"
      tail -n 40 "$f"
      echo
    done
  } > "$tmp"

  local b64 sha body
  b64=$(base64 -w0 "$tmp")
  sha=$(curl -s -H "Authorization: Bearer $GH_PAT" \
        "https://api.github.com/repos/$REPO/contents/logs/status.md" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin).get("sha",""))' 2>/dev/null)
  if [ -n "$sha" ]; then
    body=$(python3 -c 'import json,sys;print(json.dumps({"message":"codespace status","content":sys.argv[1],"sha":sys.argv[2],"branch":"main"}))' "$b64" "$sha")
  else
    body=$(python3 -c 'import json,sys;print(json.dumps({"message":"codespace status","content":sys.argv[1],"branch":"main"}))' "$b64")
  fi
  curl -s -X PUT -H "Authorization: Bearer $GH_PAT" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/contents/logs/status.md" -d "$body" >/dev/null \
    && echo "[autostart] status publicado"
  rm -f "$tmp"
}

sleep 25
publish_status
echo "[autostart] listo"
