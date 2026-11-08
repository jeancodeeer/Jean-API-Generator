#!/usr/bin/env bash
# setup-vm.sh — prepara una VM Oracle Cloud Always Free (Ampere A1, 24 GB)
# para servir una API Jean v0.7 de forma permanente (systemd).
#
# Ejecutar DENTRO de la VM (Ubuntu 22.04/24.04):
#   curl -fsSL https://raw.githubusercontent.com/jeancodeeer/jean-api/main/oracle/setup-vm.sh -o setup-vm.sh
#   sudo bash setup-vm.sh --model fenix --api-key "mi-clave"
#
# Que hace:
#   1. instala llama.cpp (prebuilt aarch64, o compila si no hay)
#   2. descarga el modelo del repo PUBLICO de HF (sin token)
#   3. crea un servicio systemd que escucha en 0.0.0.0:8890 con Bearer
#   4. abre el puerto en iptables (el Security List se abre en la consola OCI)
#   5. imprime la URL y la clave
#
# Opciones:
#   --model   fenix | grey | marvel   (default: fenix)
#   --api-key clave Bearer            (default: auto-generada)
#   --port    puerto                  (default: 8890 fenix / 8888 grey / 8889 marvel)
set -euo pipefail

MODEL="fenix"
API_KEY=""
PORT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "arg desconocido: $1" >&2; exit 1 ;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "ejecutar con sudo" >&2; exit 1; }
[ -r /etc/os-release ] || { echo "no parece Ubuntu/Debian" >&2; exit 1; }

model_file() {
  case "$1" in
    grey)   echo "jean-grey-v0.7.Q4_K_M.gguf" ;;
    marvel) echo "jean-marvel-v0.7.Q4_K_M.gguf" ;;
    fenix)
      # preferir Q5_K_M (casi sin degradacion, para 24 GB) si ya esta en HF
      local code
      code=$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 20 \
             "https://huggingface.co/JeanCoder/jean-models/resolve/main/jean-fenix-v0.7.Q5_K_M.gguf" 2>/dev/null || echo 000)
      if [ "$code" = "200" ]; then
        echo "jean-fenix-v0.7.Q5_K_M.gguf"
      else
        echo "jean-fenix-v0.7.Q4_K_M.gguf"
      fi ;;
    *) echo "modelo invalido: $1" >&2; exit 1 ;;
  esac
}

model_port() {
  case "$1" in
    grey) echo 8888 ;;
    marvel) echo 8889 ;;
    fenix) echo 8890 ;;
  esac
}

model_ctx() {
  case "$1" in
    grey) echo 16384 ;;
    marvel) echo 8192 ;;
    fenix) echo 4096 ;;
  esac
}

FILE=$(model_file "$MODEL")
[ "$PORT" -eq 0 ] && PORT=$(model_port "$MODEL")
CTX=$(model_ctx "$MODEL")
[ -z "$API_KEY" ] && API_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | cut -c1-40)

echo "[setup] modelo: $FILE  puerto: $PORT"

# 1) dependencias + llama.cpp
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates cmake build-essential git python3 unzip >/dev/null

mkdir -p /opt/jean/llama /opt/jean/gguf
if [ ! -x /opt/jean/llama/llama-server ]; then
  arch=$(uname -m)
  want=""
  [ "$arch" = "aarch64" ] && want="bin-ubuntu-aarch64"
  [ "$arch" = "x86_64" ] && want="bin-ubuntu-x64"
  url=""
  if [ -n "$want" ]; then
    url=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=3" \
          | grep -o '"browser_download_url": *"[^"]*'"$want"'\.\(tar\.gz\|zip\)"' \
          | head -1 | cut -d'"' -f4 || true)
  fi
  if [ -n "$url" ]; then
    echo "[setup] llama.cpp prebuilt ($want)"
    curl -fsSL --retry 3 "$url" -o /tmp/llama.tar.gz
    tar -xzf /tmp/llama.tar.gz -C /opt/jean/llama --strip-components=1
  else
    echo "[setup] sin prebuilt para $arch; compilando (~10 min) ..."
    [ -d /tmp/llama-src ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp /tmp/llama-src
    cmake -S /tmp/llama-src -B /tmp/llama-build -DGGML_NATIVE=ON \
          -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=OFF >/dev/null
    cmake --build /tmp/llama-build --config Release -j"$(nproc)" \
          --target llama-server >/dev/null
    cp /tmp/llama-build/bin/llama-server /opt/jean/llama/
  fi
fi
[ -x /opt/jean/llama/llama-server ] || { echo "no hay llama-server" >&2; exit 1; }

# 2) modelo desde HF publico (resume)
if [ ! -s "/opt/jean/gguf/$FILE" ]; then
  echo "[setup] descargando $FILE (~puede tardar segun tamaño) ..."
  curl -fL --retry 3 --retry-delay 2 -C - \
    "https://huggingface.co/JeanCoder/jean-models/resolve/main/$FILE" \
    -o "/opt/jean/gguf/$FILE.part"
  mv "/opt/jean/gguf/$FILE.part" "/opt/jean/gguf/$FILE"
fi

# 3) servicio systemd
cat > /etc/systemd/system/jean-api.service <<UNIT
[Unit]
Description=Jean API (llama.cpp, OpenAI-compatible)
After=network-online.target

[Service]
ExecStart=/opt/jean/llama/llama-server -m /opt/jean/gguf/$FILE \\
  --host 0.0.0.0 --port $PORT --alias jean-$MODEL -c $CTX \\
  --threads \$(nproc) --temp 0.2 --top-p 0.9 --api-key $API_KEY
Restart=always
RestartSec=5
User=root
Nice=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now jean-api.service

# 4) firewall local (el Security List de la consola OCI aparte)
iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT || true
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save >/dev/null 2>&1 || true
fi

# 5) esperar y reportar
echo "[setup] esperando a que el modelo cargue ..."
for i in $(seq 1 90); do
  sleep 5
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
    -H "Authorization: Bearer $API_KEY" "http://127.0.0.1:$PORT/v1/models" 2>/dev/null || true)
  [ "$code" = "200" ] && break
done

IP=$(curl -s --max-time 8 ifconfig.me 2>/dev/null || echo "<IP_PUBLICA>")
cat <<EOF

=== API Jean-$MODEL LISTA (systemd, reinicia sola) ===
  URL interna : http://127.0.0.1:$PORT/v1
  URL publica : http://$IP:$PORT/v1
  API key     : $API_KEY
  servicio    : systemctl {status|restart|stop} jean-api
  logs        : journalctl -u jean-api -f

RECuerda abrir el puerto $PORT en la consola OCI:
  Networking -> Virtual Cloud Networks -> tu VCN -> Security Lists ->
  Add Ingress Rule: Source 0.0.0.0/0, TCP, Destination Port $PORT
EOF
