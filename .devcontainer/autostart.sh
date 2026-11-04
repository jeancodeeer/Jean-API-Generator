#!/usr/bin/env bash
# postStartCommand: arranca la API sola en cada inicio del Codespace.
# Requiere JEAN_API_KEY. Modelos desde HF (JEAN_SOURCE=hf).
# Publica logs + URLs de tunnel + self-test en logs/status.md (si hay GH_PAT).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REPO="${JEAN_GH_REPO:-jeancodeeer/jean-api}"

# Auto-actualizacion: si el repo trae cambios, re-ejecutar la version nueva.
# (el workspace del Codespace solo se refresca al reconstruir, no al reiniciar)
if [ "${JEAN_NO_SELFUPDATE:-0}" != "1" ] && [ -d "$ROOT/.git" ]; then
  if git -C "$ROOT" pull --ff-only --quiet 2>/dev/null; then
    echo "[autostart] repo actualizado"
  fi
  export JEAN_NO_SELFUPDATE=1
  exec bash "$ROOT/.devcontainer/autostart.sh" "$@"
fi

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

# --- cloudflared: expone el puerto sin depender del reenvio de GitHub --------
CF="$HOME/bin/cloudflared"
install_cf() {
  [ -x "$CF" ] && return 0
  mkdir -p "$HOME/bin"
  {
    echo "[cf] descargando cloudflared $(date -u +%FT%TZ)"
    curl -fL --retry 3 -o "$CF" \
      https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x "$CF"
    echo "[cf] descarga rc=$?"
    "$CF" --version || echo "[cf] no ejecuta"
  } >> /tmp/cf-install.log 2>&1
  [ -x "$CF" ]
}

start_tunnel() {
  local port="$1" name="$2"
  install_cf || { echo "[autostart] sin cloudflared (ver /tmp/cf-install.log)"; return 0; }
  pkill -f "cloudflared.*localhost:${port}" 2>/dev/null || true
  nohup "$CF" tunnel --url "http://localhost:${port}" --no-autoupdate \
    > "/tmp/cf-$name.log" 2>&1 &
  echo "[autostart] tunnel $name -> :$port (pid $!)"
}

start_model grey 8888
MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$MEM_MB" -ge 14000 ]; then
  start_model marvel 8889
else
  echo "[autostart] RAM ${MEM_MB}MB: solo grey (marvel necesita 16GB)"
fi

start_tunnel 8888 grey
[ "$MEM_MB" -ge 14000 ] && start_tunnel 8889 marvel

# --- status para depurar sin SSH -------------------------------------------
publish_status() {
  [ -z "${GH_PAT:-}" ] && return 0
  local tmp; tmp=$(mktemp)
  {
    echo "# status $(date -u +%FT%TZ)"
    echo
    echo "## RAM"; free -m || true
    echo
    echo "## procesos"; pgrep -af llama-server || echo "(ninguno)"
    pgrep -af cloudflared || true
    echo
    for name in grey marvel; do
      local url
      url=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "/tmp/cf-$name.log" 2>/dev/null | head -1)
      [ -n "$url" ] && echo "- **$name**: $url"
    done
    echo
    echo "## self-test"
    for port in 8888 8889; do
      local out
      out=$(curl -s -m 8 -H "Authorization: Bearer $JEAN_API_KEY" \
            "http://localhost:$port/v1/models" 2>/dev/null | head -c 200)
      [ -n "$out" ] && echo "- :$port -> $out"
    done
    echo
    for f in /tmp/cf-install.log /tmp/cf-grey.log /tmp/cf-marvel.log; do
      [ -f "$f" ] || continue
      echo "## $(basename "$f")"; tail -n 12 "$f"; echo
    done
    for f in /tmp/serve-*.log; do
      [ -f "$f" ] || continue
      echo "## $(basename "$f")"; tail -n 15 "$f"; echo
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

# espera activa a que el servidor responda (max 3 min)
for i in $(seq 1 36); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    -H "Authorization: Bearer $JEAN_API_KEY" http://localhost:8888/v1/models 2>/dev/null || true)
  [ "$code" = "200" ] && break
  sleep 5
done
publish_status
echo "[autostart] listo"
