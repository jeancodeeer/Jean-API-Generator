#!/usr/bin/env bash
# Watchdog: cada 60s comprueba que cada modelo y su tunel sigan vivos.
# Se lanza en segundo plano desde autostart.sh (setsid, sobrevive al cierre de sesion).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REPO="${JEAN_GH_REPO:-jeancodeeer/jean-api}"
CF="$HOME/bin/cloudflared"

tunnel_url() {
  grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "/tmp/cf-$1.log" 2>/dev/null \
    | grep -v '//api\.' | head -1
}

publish_urls() {
  [ -z "${GH_PAT:-}" ] && return 0
  local tmp; tmp=$(mktemp)
  {
    local g m
    g=$(tunnel_url grey);   [ -n "$g" ] && echo "grey=${g}/v1"
    m=$(tunnel_url marvel); [ -n "$m" ] && echo "marvel=${m}/v1"
  } > "$tmp"
  local b64 sha body
  b64=$(base64 -w0 "$tmp")
  sha=$(curl -s -H "Authorization: Bearer $GH_PAT" \
        "https://api.github.com/repos/$REPO/contents/logs/urls.txt" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin).get("sha",""))' 2>/dev/null)
  if [ -n "$sha" ]; then
    body=$(python3 -c 'import json,sys;print(json.dumps({"message":"urls","content":sys.argv[1],"sha":sys.argv[2],"branch":"main"}))' "$b64" "$sha")
  else
    body=$(python3 -c 'import json,sys;print(json.dumps({"message":"urls","content":sys.argv[1],"branch":"main"}))' "$b64")
  fi
  curl -s -X PUT -H "Authorization: Bearer $GH_PAT" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/contents/logs/urls.txt" -d "$body" >/dev/null
  rm -f "$tmp"
}

declare -A FAILS=()
check_model() {
  local model="$1" port="$2"
  local code
  # /health no requiere clave y responde aunque el modelo este generando.
  # 200 = listo, 503 = cargando: ambos son un servidor vivo.
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 \
    "http://localhost:$port/health" 2>/dev/null || true)
  if [ "$code" = "200" ] || [ "$code" = "503" ]; then
    FAILS[$port]=0
    return 0
  fi
  # Un modelo en CPU ocupado puede tardar en contestar: solo se relanza
  # tras 3 comprobaciones fallidas seguidas (~3 minutos) o si el proceso no existe.
  FAILS[$port]=$(( ${FAILS[$port]:-0} + 1 ))
  if pgrep -f "llama-server.*--port ${port}" >/dev/null 2>&1 && [ "${FAILS[$port]}" -lt 3 ]; then
    echo "[watchdog $(date -u +%FT%TZ)] $model (:${port}) sin respuesta (code=${code:-none}, ${FAILS[$port]}/3); espero"
    return 0
  fi
  FAILS[$port]=0
  # el servidor de control esta cargando un modelo en este puerto: no tocar
  [ -e "/tmp/jean-slot-${port}.lock" ] && return 0
  echo "[watchdog $(date -u +%FT%TZ)] $model (:${port}) no responde (code=${code:-none}); relanzando"
  pkill -f "llama-server.*--port ${port}" 2>/dev/null || true
  sleep 2
  # modelo personalizado (cargado desde JeanCode): se relanza el mismo, no el de Jean
  if [ -f "/tmp/jean-slot-${port}.env" ]; then
    set -a; . "/tmp/jean-slot-${port}.env"; set +a
    model=custom
  fi
  PORT="$port" JEAN_SOURCE="${JEAN_SOURCE:-hf}" JEAN_GGUF_DIR="$ROOT/gguf" \
    setsid nohup bash "$ROOT/serve.sh" "$model" >> "/tmp/serve-$model.log" 2>&1 &
}

check_tunnel() {
  local name="$1" port="$2"
  if pgrep -f "cloudflared.*localhost:${port}" >/dev/null 2>&1; then
    return 0
  fi
  echo "[watchdog $(date -u +%FT%TZ)] tunnel $name caido; relanzando"
  [ -x "$CF" ] || return 0
  pkill -f "cloudflared.*localhost:${port}" 2>/dev/null || true
  setsid nohup "$CF" tunnel --url "http://localhost:${port}" --no-autoupdate \
    > "/tmp/cf-$name.log" 2>&1 &
  sleep 20
  publish_urls
}

echo "[watchdog] arriba $(date -u +%FT%TZ)"
while true; do
  sleep 60
  check_model grey 8888
  MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  if [ "$MEM_MB" -ge 14000 ]; then
    check_model marvel 8889
  fi
  check_tunnel grey 8888
  [ "$MEM_MB" -ge 14000 ] && check_tunnel marvel 8889
done
