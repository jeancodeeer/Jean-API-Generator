#!/usr/bin/env bash
# Jean API en GitHub Codespaces (CPU).
# Uso:  bash serve.sh {marvel|grey|fenix}
# Requiere secrets de Codespaces: HF_TOKEN (read del repo de modelos)
# y JEAN_API_KEY (clave Bearer de la API). Se configuran una sola vez.
set -euo pipefail
MODEL="${1:-marvel}"
case "$MODEL" in
  marvel|grey|fenix) ;;
  *) echo "uso: bash serve.sh {marvel|grey|fenix}" >&2; exit 1 ;;
esac
FILE="jean-${MODEL}-v0.7.Q4_K_M.gguf"
REPO="${JEAN_MODEL_REPO:-JeanCoder/jean-models}"
CTX=8192; [ "$MODEL" = "grey" ] && CTX=16384; [ "$MODEL" = "fenix" ] && CTX=16384
GGDIR="$HOME/gguf"; mkdir -p "$GGDIR"
python3 -m pip install -q -U "huggingface_hub[cli]" 2>/dev/null || true
if [ ! -s "$GGDIR/$FILE" ]; then
  echo "[serve] descargando $FILE desde $REPO ..."
  huggingface-cli download "$REPO" "$FILE" --token "${HF_TOKEN:?falta el secret HF_TOKEN}" \
    --local-dir "$GGDIR" --no-progress-bar
fi
BIN=$(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1 || true)
if [ -z "${BIN:-}" ]; then
  echo "[serve] descargando llama.cpp prebuilt (CPU) ..."
  URL=$(curl -s https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*bin-ubuntu-x64\.zip"' | head -1 | cut -d'"' -f4)
  [ -n "${URL:-}" ] || { echo "no encontré binario ubuntu-x64" >&2; exit 1; }
  curl -sL "$URL" -o /tmp/llama.zip
  mkdir -p "$HOME/llama"; unzip -o -q /tmp/llama.zip -d "$HOME/llama"
  BIN=$(find "$HOME/llama" -name llama-server -type f | head -1)
fi
echo "[serve] lanzando jean-$MODEL en :8888 (ctx $CTX)"
exec "$BIN" -m "$GGDIR/$FILE" --host 0.0.0.0 --port 8888 \
  --alias "jean-$MODEL" -c "$CTX" --threads 4 \
  --temp 0.2 --top-p 0.9 --api-key "${JEAN_API_KEY:-}"
