#!/usr/bin/env bash
# Jean API en GitHub Codespaces (CPU).
# Uso:  bash serve.sh {grey|marvel|fenix}
#
# Env:
#   JEAN_API_KEY   (obligatorio) clave Bearer de la API
#   HF_TOKEN       token HF (solo si JEAN_SOURCE=hf y el repo es privado)
#   JEAN_SOURCE    github (default) | hf
#   JEAN_REPO      repo HF de modelos (default JeanCoder/jean-models)
#   JEAN_GH_REPO   repo GitHub con el release de modelos (default jeancodeeer/jean-api)
#   JEAN_GH_TAG    tag del release (default v0.7-models)
#   PORT           puerto (default 8888)
set -euo pipefail

MODEL="${1:-grey}"
case "$MODEL" in
  grey|marvel|fenix) ;;
  *) echo "uso: bash serve.sh {grey|marvel|fenix}" >&2; exit 1 ;;
esac

PORT="${PORT:-8888}"
SRC="${JEAN_SOURCE:-hf}"
GH_REPO="${JEAN_GH_REPO:-jeancodeeer/jean-api}"
GH_TAG="${JEAN_GH_TAG:-v0.7-models}"
HF_REPO="${JEAN_REPO:-JeanCoder/jean-models}"
FILE="jean-${MODEL}-v0.7.Q4_K_M.gguf"
BASE="$(basename "$FILE" .gguf)"
GGDIR="${JEAN_GGUF_DIR:-$HOME/gguf}"
mkdir -p "$GGDIR"

# Contexto: Grey aguanta 16k en 4c; 27B (Fenix) no cabe en 16 GB de RAM.
CTX=8192
[ "$MODEL" = "grey" ] && CTX=16384
[ "$MODEL" = "fenix" ] && CTX=8192

# ---------------------------------------------------------------- llama.cpp
find_server() { find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1 || true; }

install_llama() {
  echo "[serve] instalando llama.cpp prebuilt (CPU) ..."
  local api="https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5"
  local url
  url=$(curl -s "$api" \
    | grep -o '"browser_download_url": *"[^"]*bin-ubuntu-x64\.tar\.gz"' \
    | head -1 | cut -d'"' -f4)
  [ -n "${url:-}" ] || { echo "no encontré binario ubuntu-x64" >&2; exit 1; }
  mkdir -p "$HOME/llama"
  curl -sL "$url" | tar -xz -C "$HOME/llama"
}

# ---------------------------------------------------------------- descarga
download_github() {
  local api="https://api.github.com/repos/$GH_REPO/releases/tags/$GH_TAG"
  local auth=()
  [ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GH_TOKEN")

  if [ ! -s "$GGDIR/$FILE" ]; then
    echo "[serve] $FILE no está; bajando partes de $GH_REPO@$GH_TAG ..."
    local tmp="$GGDIR/.parts-$BASE"
    rm -rf "$tmp"; mkdir -p "$tmp"
    local manifest
    manifest=$(curl -sL "${auth[@]}" "$api" \
      | grep -o '"browser_download_url": *"[^"]*'"$BASE"'\.manifest\.json"' \
      | head -1 | cut -d'"' -f4)
    [ -n "${manifest:-}" ] || { echo "no encontré $BASE.manifest.json en el release" >&2; exit 1; }
    curl -sL "${auth[@]}" "$manifest" -o "$tmp/manifest.json"

    python3 - "$tmp/manifest.json" "$api" "$GGDIR/$FILE" <<'PY'
import json, subprocess, sys, urllib.request, os
man, api, out = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(man))
import urllib.request as u
req = u.Request(api, headers={"Accept": "application/vnd.github+json"})
if os.environ.get("GH_TOKEN"):
    req.add_header("Authorization", "Bearer " + os.environ["GH_TOKEN"])
rel = json.load(u.urlopen(req))
urls = {a["name"]: a["browser_download_url"] for a in rel["assets"]}
tmpdir = os.path.dirname(man)
with open(out, "wb") as g:
    for p in m["parts"]:
        dst = os.path.join(tmpdir, p["name"])
        if not os.path.exists(dst) or os.path.getsize(dst) != p["bytes"]:
            print(f"[serve]   bajando {p['name']} ({p['bytes']/2**30:.2f} GiB)")
            u.urlretrieve(urls[p["name"]], dst)
        with open(dst, "rb") as f:
            while True:
                b = f.read(8 << 20)
                if not b: break
                g.write(b)
        os.remove(dst)
print("[serve] reconstruido", out)
PY
    echo "[serve] verificando sha256 ..."
    local want got
    want=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['sha256'])" "$tmp/manifest.json")
    got=$(sha256sum "$GGDIR/$FILE" | cut -d' ' -f1)
    [ "$want" = "$got" ] || { echo "sha256 NO coincide (esperado $want, real $got)" >&2; rm -f "$GGDIR/$FILE"; exit 1; }
    echo "[serve] sha256 OK"
    rm -rf "$tmp"
  fi
}

download_hf() {
  [ -s "$GGDIR/$FILE" ] && return 0
  echo "[serve] descargando $FILE desde HF $HF_REPO ..."
  python3 -m pip install -q -U "huggingface_hub[cli]" 2>/dev/null || true
  huggingface-cli download "$HF_REPO" "$FILE" --token "${HF_TOKEN:?falta HF_TOKEN}" \
    --local-dir "$GGDIR" --no-progress-bar
}

# ---------------------------------------------------------------- main
BIN=$(find_server)
[ -n "$BIN" ] || { install_llama; BIN=$(find_server); }
[ -n "$BIN" ] || { echo "no pude instalar llama-server" >&2; exit 1; }

case "$SRC" in
  hf)     download_hf ;;
  github) download_github ;;
  *) echo "JEAN_SOURCE inválido: $SRC" >&2; exit 1 ;;
esac

THREADS=$(nproc 2>/dev/null || echo 4)
echo "[serve] jean-$MODEL en :$PORT (ctx $CTX, $THREADS hilos)"
exec "$BIN" -m "$GGDIR/$FILE" --host 0.0.0.0 --port "$PORT" \
  --alias "jean-$MODEL" -c "$CTX" --threads "$THREADS" \
  --temp 0.2 --top-p 0.9 --api-key "${JEAN_API_KEY:-}"
