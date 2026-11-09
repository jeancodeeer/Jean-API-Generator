#!/usr/bin/env bash
# postStartCommand: arranca la API sola en cada inicio del Codespace.
# Requiere JEAN_API_KEY. Modelos desde HF (JEAN_SOURCE=hf).
# Escribe logs + self-test en ~/logs/ (SOLO local: nunca publica URLs al repo).
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

# Router + control (:8899) y watchdog: en TODOS los modos. El router es la URL unica para
# JeanCode (todos los modelos, incluidos los GGUF de Hugging Face cargados desde el cliente).
start_services() {
  if ! pgrep -f "control_server.py" >/dev/null 2>&1; then
    setsid nohup python3 "$ROOT/control/control_server.py" > /tmp/control.log 2>&1 < /dev/null &
    echo "[autostart] router + control en :8899"
  fi
  if ! pgrep -f "watchdog.sh" >/dev/null 2>&1; then
    setsid nohup bash "$HERE/watchdog.sh" > /tmp/watchdog.log 2>&1 < /dev/null &
    echo "[autostart] watchdog lanzado"
  fi
}

# Modo guardado en el WORKSPACE (persiste entre rebuilds):
#   echo fenix > "$ROOT/.jean-mode"  -> solo fenix en :8890 (el GGUF que quepa en la RAM)
#   rm "$ROOT/.jean-mode"            -> estandar (grey + marvel)
MODE_FILE="$ROOT/.jean-mode"
MODE=$(cat "$MODE_FILE" 2>/dev/null || echo standard)
if [ "$MODE" = "fenix" ]; then
  mkdir -p "$ROOT/gguf"
  # FENIX_FILE vacio = serve.sh elige en Hugging Face el GGUF de Fenix que cabe en esta RAM;
  # si ninguno cabe, el motivo aparece en el router (/v1/models -> jean.unavailable)
  if ! pgrep -f "llama-server.*--port 8890" >/dev/null 2>&1; then
    PORT=8890 JEAN_SOURCE=hf JEAN_GGUF_DIR="$ROOT/gguf" \
      FENIX_FILE="${FENIX_FILE:-}" FENIX_CTX="${FENIX_CTX:-8192}" \
      setsid nohup bash "$ROOT/serve.sh" fenix > /tmp/serve-fenix.log 2>&1 < /dev/null &
  fi
  [ -x "$HOME/bin/cloudflared" ] && setsid nohup "$HOME/bin/cloudflared" tunnel --url http://localhost:8890 --no-autoupdate > /tmp/cf-fenix.log 2>&1 &
  start_services
  echo "[autostart] modo FENIX en :8890 (persistente via $MODE_FILE)"
  exit 0
fi

start_model() {
  local model="$1" port="$2"
  if pgrep -f "llama-server.*--port ${port}" >/dev/null 2>&1; then
    echo "[autostart] $model ya corriendo en :$port"
    return 0
  fi
  echo "[autostart] lanzando $model en :$port"
  # los GGUF van al WORKSPACE (persiste entre rebuilds del codespace)
  mkdir -p "$ROOT/gguf"
  PORT="$port" JEAN_SOURCE="${JEAN_SOURCE:-hf}" JEAN_GGUF_DIR="$ROOT/gguf" \
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

tunnel_url() {  # URL publica de un tunel (excluye el endpoint api. de Cloudflare)
  grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "/tmp/cf-$1.log" 2>/dev/null \
    | grep -v '//api\.' | head -1
}

start_tunnel() {
  local port="$1" name="$2"
  install_cf || { echo "[autostart] sin cloudflared (ver /tmp/cf-install.log)"; return 0; }
  local attempt
  for attempt in 1 2 3 4 5; do
    pkill -f "cloudflared.*localhost:${port}" 2>/dev/null || true
    sleep 1
    : > "/tmp/cf-$name.log"
    setsid nohup "$CF" tunnel --url "http://localhost:${port}" --no-autoupdate \
      > "/tmp/cf-$name.log" 2>&1 &
    local i
    for i in $(seq 1 15); do
      sleep 2
      if [ -n "$(tunnel_url "$name")" ]; then
        echo "[autostart] tunnel $name listo (intento $attempt)"
        return 0
      fi
    done
    echo "[autostart] tunnel $name fallo intento $attempt"
    pkill -f "cloudflared.*localhost:${port}" 2>/dev/null || true
    sleep 8
  done
  echo "[autostart] tunnel $name FALLO tras 5 intentos"
}

start_model grey 8888
MEM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$MEM_MB" -ge 14000 ]; then
  start_model marvel 8889
else
  echo "[autostart] RAM ${MEM_MB}MB: solo grey (marvel necesita 16GB)"
fi
if [ "$MEM_MB" -ge 30000 ]; then
  start_model fenix 8890
else
  echo "[autostart] RAM ${MEM_MB}MB: sin fenix (necesita 32GB)"
fi

start_tunnel 8888 grey
[ "$MEM_MB" -ge 14000 ] && start_tunnel 8889 marvel
[ "$MEM_MB" -ge 30000 ] && start_tunnel 8890 fenix

# watchdog (relanza modelos caidos) + router/control (:8899: URL unica y carga de modelos de HF)
start_services

# --- status para depurar sin SSH -------------------------------------------
publish_status() {
  [ -z "${GH_PAT:-}" ] && return 0
  local tmp; tmp=$(mktemp)
  {
    echo "# status $(date -u +%FT%TZ)"
    echo
    echo "version: $(git -C "$ROOT" log -1 --oneline 2>/dev/null || echo '?')"
    echo
    echo "## RAM"; free -m || true
    echo
    echo "## procesos"; pgrep -af llama-server || echo "(ninguno)"
    pgrep -af cloudflared || true
    echo
    # URLs: solo local (nada de nombres de codespace en este script)
    echo "## endpoints locales"
    echo "- grey: http://127.0.0.1:8888/v1"
    [ "$MEM_MB" -ge 14000 ] && echo "- marvel: http://127.0.0.1:8889/v1"
    echo
    echo "## URLs de respaldo (Cloudflare)"
    for name in grey marvel; do
      local url
      url=$(tunnel_url "$name")
      [ -n "$url" ] && echo "- **$name**: $url"
    done
    echo
    echo "## self-test"
    for port in 8888 8889 8890; do
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

  # Version LOCAL: los logs y las URLs quedan en el Codespace; nada via a GitHub.
  mkdir -p "$HOME/logs"
  cp "$tmp" "$HOME/logs/status.md"
  {
    echo "grey_local=127.0.0.1:8888/v1"
    [ "$MEM_MB" -ge 14000 ] && echo "marvel_local=127.0.0.1:8889/v1"
    local g m
    g=$(tunnel_url grey);   [ -n "$g" ] && echo "grey_cloudflare=${g}/v1"
    m=$(tunnel_url marvel); [ -n "$m" ] && echo "marvel_cloudflare=${m}/v1"
  } > "$HOME/logs/urls.txt"
  echo "[autostart] status/urls escritos en ~/logs (local)"
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
