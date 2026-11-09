#!/usr/bin/env bash
# jean-api-generator.sh — generador de APIs Jean v0.7 para macOS / Linux / WSL.
# Igual de filosofia que jean-api-generator.ps1 (Windows): cada instancia
# genera su propia clave, solo 127.0.0.1, nada en repos.
#
# Uso:
#   ./jean-api-generator.sh start grey                # clave auto-generada
#   ./jean-api-generator.sh start marvel --port 8889 --api-key "mi-clave"
#   ./jean-api-generator.sh status
#   ./jean-api-generator.sh stop --port 8888
#   ./jean-api-generator.sh list
set -uo pipefail

ACTION="${1:-status}"
MODEL="grey"
PORT=0
API_KEY=""
THREADS="${JEAN_THREADS:-4}"
CTX=0

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    grey|marvel|fenix) MODEL="$1" ;;
    --port) PORT="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    *) echo "arg desconocido: $1" >&2; exit 1 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
GGDIR="$HERE/gguf"
LOGDIR="$HERE/logs"
DOWNDIR="$HERE/down"
mkdir -p "$GGDIR" "$LOGDIR" "$DOWNDIR"

HF_BASE="https://huggingface.co/JeanCoder/jean-models/resolve/main"

model_file() {
  case "$1" in
    grey)   echo "jean-grey-v0.7.Q4_K_M.gguf" ;;
    marvel) echo "jean-marvel-v0.7.Q4_K_M.gguf" ;;
    fenix)  echo "jean-fenix-v0.7.Q4_K_M.gguf" ;;
  esac
}

model_ctx() {
  # RAM-aware: 128k solo en maquinas grandes (KV q8_0 ~2 GB por modelo a 128k)
  local ram_gb=0
  if command -v free >/dev/null 2>&1; then
    ram_gb=$(( $(free -m | awk '/^Mem:/{print $2}') / 1024 ))
  else
    ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))
  fi
  case "$1" in
    fenix) echo 131072 ;;
    *) if [ "$ram_gb" -ge 20 ]; then echo 131072
       elif [ "$ram_gb" -ge 12 ]; then echo 65536
       else echo 8192; fi ;;
  esac
}

model_port() {
  case "$1" in
    grey)   echo 8888 ;;
    marvel) echo 8889 ;;
    fenix)  echo 8890 ;;
  esac
}

model_ram() {
  case "$1" in
    grey)   echo 4 ;;
    marvel) echo 6 ;;
    fenix)  echo 32 ;;
  esac
}

log() { echo "[$(date '+%F %T')] $*"; }

# fenix: si existe la version Q5_K_M (casi sin degradacion) usarla
fenix_pick() {
  local q5 q4
  q5=$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 15 \
        "$HF_BASE/jean-fenix-v0.7.Q5_K_M.gguf" 2>/dev/null || echo 000)
  if [ "$q5" = "200" ]; then
    echo "jean-fenix-v0.7.Q5_K_M.gguf"
  else
    echo "jean-fenix-v0.7.Q4_K_M.gguf"
  fi
}

# ---------------------------------------------------------------- acciones
if [ "$ACTION" = "list" ]; then
  echo "modelos disponibles (HF publico JeanCoder/jean-models):"
  printf "  %-7s %s\n" grey   "$(model_file grey)   (RAM >= $(model_ram grey) GB)"
  printf "  %-7s %s\n" marvel "$(model_file marvel)   (RAM >= $(model_ram marvel) GB)"
  printf "  %-7s %s (RAM >= %s GB)\n" fenix "fenix Q4_K_M o Q5_K_M si existe" "$(model_ram fenix)"
  exit 0
fi

if [ "$ACTION" = "status" ]; then
  found=0
  while read -r pid; do
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || \
      cmdline=$(ps -o command= -p "$pid" 2>/dev/null)
    case "$cmdline" in
      *llama-server*)
        port=$(echo "$cmdline" | grep -oE -- '--port [0-9]+' | awk '{print $2}')
        alias=$(echo "$cmdline" | grep -oE -- '--alias jean-[a-z]+' | head -1)
        echo "PID $pid  puerto ${port:-?}  ${alias:-?}"
        found=1 ;;
    esac
  done < <(pgrep -x llama-server 2>/dev/null || true)
  [ "$found" = 0 ] && echo "no hay APIs Jean corriendo"
  exit 0
fi

if [ "$ACTION" = "stop" ]; then
  [ "$PORT" -eq 0 ] && { echo "indica el puerto: stop --port 8888" >&2; exit 1; }
  pids=$(pgrep -x llama-server 2>/dev/null || true)
  killed=0
  for pid in $pids; do
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || \
      cmdline=$(ps -o command= -p "$pid" 2>/dev/null)
    case "$cmdline" in
      *"--port $PORT "*|*"--port $PORT")
        kill "$pid" && log "detenida API en puerto $PORT (PID $pid)"; killed=1 ;;
    esac
  done
  [ "$killed" = 0 ] && echo "no hay proceso en el puerto $PORT"
  exit 0
fi

if [ "$ACTION" != "start" ]; then
  echo "uso: $0 {start|stop|status|list}" >&2
  exit 1
fi

case "$MODEL" in
  grey|marvel|fenix) ;;
  *) echo "modelo invalido: $MODEL" >&2; exit 1 ;;
esac

# comprobar RAM total (GB)
if command -v free >/dev/null 2>&1; then
  ram_gb=$(( $(free -m | awk '/^Mem:/{print $2}') / 1024 ))
else
  ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))
fi
need=$(model_ram "$MODEL")
if [ "$ram_gb" -lt "$need" ]; then
  echo "Jean-$MODEL necesita >= ${need} GB de RAM; esta maquina tiene ${ram_gb} GB." >&2
  echo "Usa un modelo mas pequeno o una maquina en la nube (ver README)." >&2
  exit 1
fi

[ "$PORT" -eq 0 ] && PORT=$(model_port "$MODEL")
[ "$CTX" -eq 0 ] && CTX=$(model_ctx "$MODEL")

if [ -z "$API_KEY" ]; then
  if command -v openssl >/dev/null 2>&1; then
    API_KEY=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-40)
  else
    API_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | cut -c1-40)
  fi
  log "API key auto-generada para esta instancia"
fi

# ---------------------------------------------------------------- llama.cpp
find_server() {
  for c in "$HOME/llama/bin" "$HOME/llama" "$HERE/llama"; do
    [ -x "$c/llama-server" ] && { echo "$c/llama-server"; return 0; }
  done
  find "$HOME/llama" "$HERE" -name llama-server -type f 2>/dev/null | head -1
  return 0
}

os_name=$(uname -s); arch=$(uname -m)
install_llama() {
  log "descargando llama.cpp prebuilt ($os_name/$arch) ..."
  local want
  case "$os_name/$arch" in
    Darwin/arm64)  want="bin-macos-arm64" ;;
    Darwin/x86_64) want="bin-macos-x64" ;;
    Linux/x86_64)  want="bin-ubuntu-x64" ;;
    Linux/aarch64|Linux/arm64) want="bin-ubuntu-aarch64" ;;
    *) echo "plataforma no soportada: $os_name/$arch" >&2; exit 1 ;;
  esac
  local url
  url=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=3" \
        | grep -o '"browser_download_url": *"[^"]*'"$want"'\.\(tar\.gz\|zip\)"' \
        | head -1 | cut -d'"' -f4)
  [ -n "${url:-}" ] || { echo "no encontre prebuilt $want; compila llama.cpp manualmente" >&2; exit 1; }
  mkdir -p "$HOME/llama"
  curl -fL --retry 3 "$url" -o "$DOWNDIR/llama.tar.gz"
  case "$url" in
    *.zip)   unzip -q -o "$DOWNDIR/llama.tar.gz" -d "$HOME/llama" ;;
    *.tar.gz) tar -xzf "$DOWNDIR/llama.tar.gz" -C "$HOME/llama" --strip-components=1 ;;
  esac
}

BIN=$(find_server)
if [ -z "$BIN" ]; then install_llama; BIN=$(find_server); fi
[ -n "$BIN" ] || { echo "no pude conseguir llama-server" >&2; exit 1; }

# ---------------------------------------------------------------- descarga
FILE=$(model_file "$MODEL")
if [ "$MODEL" = "fenix" ]; then
  FILE=$(fenix_pick)
  log "fenix: usando $FILE"
fi
DEST="$GGDIR/$FILE"
if [ ! -s "$DEST" ]; then
  log "descargando $FILE desde HF publico (resume activo) ..."
  curl -fL --retry 3 --retry-delay 2 -C - "$HF_BASE/$FILE" -o "$DEST.part" \
    && mv "$DEST.part" "$DEST"
fi

# ---------------------------------------------------------------- lanzar
OUTLOG="$LOGDIR/jean-$MODEL-$PORT.out.log"
ERRLOG="$LOGDIR/jean-$MODEL-$PORT.err.log"
log "lanzando jean-$MODEL en http://127.0.0.1:$PORT (ctx $CTX, $THREADS hilos)"
# clave por entorno (LLAMA_API_KEY): como argumento se veria en la lista de procesos
LLAMA_API_KEY="$API_KEY" nohup "$BIN" -m "$DEST" --host 127.0.0.1 --port "$PORT" --alias "jean-$MODEL" \
  -c "$CTX" --threads "$THREADS" -ctk q8_0 -ctv q8_0 \
  --temp 0.2 --top-p 0.9 \
  > "$OUTLOG" 2> "$ERRLOG" &
SRV_PID=$!
( sleep 2; renice -n 10 -p "$SRV_PID" >/dev/null 2>&1 ) || true

printf '%s' "$API_KEY" > "$HERE/key-$PORT.txt"
[ -f "$HERE/.gitignore" ] || printf 'gguf/\ndown/\nlogs/\nkey-*.txt\n*.part\n' > "$HERE/.gitignore"

log "esperando a que el modelo cargue ..."
ok=0
for i in $(seq 1 90); do
  sleep 5
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    -H "Authorization: Bearer $API_KEY" "http://127.0.0.1:$PORT/v1/models" 2>/dev/null || true)
  [ "$code" = "200" ] && { ok=1; break; }
done
if [ "$ok" != 1 ]; then
  log "el servidor no respondio; mira $ERRLOG"
  exit 1
fi

cat <<EOF

=== API Jean-$MODEL LISTA ===
  URL     : http://127.0.0.1:$PORT/v1
  API key : $API_KEY   (guardada en $HERE/key-$PORT.txt)
  PID     : $SRV_PID  (prioridad baja)

prueba:
  curl http://127.0.0.1:$PORT/v1/chat/completions -H "Authorization: Bearer <clave>" \\
       -H "Content-Type: application/json" \\
       -d '{"model":"jean-$MODEL","messages":[{"role":"user","content":"hola"}]}'

detener:  $0 stop --port $PORT
EOF
