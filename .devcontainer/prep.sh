#!/usr/bin/env bash
# postCreateCommand: pre-descarga llama.cpp + Marvel para que el primer
# arranque de la API tarde segundos, no minutos. Idempotente.
set -uo pipefail
python3 -m pip install -q -U "huggingface_hub[cli]" 2>/dev/null || true
if [ -n "${HF_TOKEN:-}" ] && [ ! -s "$HOME/gguf/jean-marvel-v0.7.Q4_K_M.gguf" ]; then
  mkdir -p "$HOME/gguf"
  echo "[prep] pre-descargando Marvel (4.7 GB) desde HF Hub ..."
  huggingface-cli download "${JEAN_MODEL_REPO:-JeanCoder/jean-models}" \
    jean-marvel-v0.7.Q4_K_M.gguf --token "$HF_TOKEN" \
    --local-dir "$HOME/gguf" --no-progress-bar || echo "[prep] Marvel falló (se baja on-demand)"
fi
if [ -z "$(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1)" ]; then
  URL=$(curl -s https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*bin-ubuntu-x64\.zip"' | head -1 | cut -d'"' -f4)
  if [ -n "${URL:-}" ]; then
    curl -sL "$URL" -o /tmp/llama.zip && mkdir -p "$HOME/llama" \
      && unzip -o -q /tmp/llama.zip -d "$HOME/llama"
  fi
fi
echo "[prep] listo: $(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1)"
