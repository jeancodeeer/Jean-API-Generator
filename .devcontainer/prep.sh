#!/usr/bin/env bash
# postCreateCommand: pre-descarga llama.cpp + modelos para que el primer
# arranque de la API tarde segundos, no minutos. Idempotente.
set -uo pipefail

python3 -m pip install -q -U "huggingface_hub[cli]" 2>/dev/null || true

mkdir -p "$HOME/gguf"
if [ -n "${HF_TOKEN:-}" ]; then
  for f in jean-grey-v0.7.Q4_K_M.gguf jean-marvel-v0.7.Q4_K_M.gguf; do
    [ -s "$HOME/gguf/$f" ] && continue
    echo "[prep] bajando $f desde HF ..."
    huggingface-cli download "${JEAN_MODEL_REPO:-JeanCoder/jean-models}" "$f" \
      --token "$HF_TOKEN" --local-dir "$HOME/gguf" --no-progress-bar \
      || echo "[prep] $f fallo (se baja on-demand)"
  done
else
  echo "[prep] sin HF_TOKEN: modelos on-demand"
fi

if [ -z "$(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1)" ]; then
  echo "[prep] instalando llama.cpp prebuilt (CPU) ..."
  URL=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=3" \
        | grep -o '"browser_download_url": *"[^"]*bin-ubuntu-x64\.tar\.gz"' \
        | head -1 | cut -d'"' -f4)
  if [ -n "${URL:-}" ]; then
    mkdir -p "$HOME/llama"
    curl -sL "$URL" | tar -xz -C "$HOME/llama"
  fi
fi

echo "[prep] listo: $(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1)"
ls -la "$HOME/gguf" 2>/dev/null | head -5
