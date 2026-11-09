#!/usr/bin/env bash
# postCreateCommand: pre-descarga llama.cpp + modelos para que el primer
# arranque de la API tarde segundos, no minutos. Idempotente.
set -uo pipefail

GGDIR="$(cd "$(dirname "$0")/.." && pwd)/gguf"   # workspace: persiste entre rebuilds
mkdir -p "$GGDIR"

AUTH=()
[ -n "${HF_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $HF_TOKEN")
for f in jean-grey-v0.7.Q4_K_M.gguf jean-marvel-v0.7.Q4_K_M.gguf; do
  [ -s "$GGDIR/$f" ] && continue
  echo "[prep] bajando $f desde HF ..."
  rm -f "$GGDIR/$f.part"
  curl -fL --retry 3 "${AUTH[@]}" \
    "https://huggingface.co/${JEAN_MODEL_REPO:-JeanCoder/jean-models}/resolve/main/$f" \
    -o "$GGDIR/$f.part" && mv "$GGDIR/$f.part" "$GGDIR/$f" \
    || echo "[prep] $f fallo (se baja on-demand)"
done

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

echo "[prep] llama-server: $(find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1)"
ls -la "$GGDIR" 2>/dev/null | head -5
