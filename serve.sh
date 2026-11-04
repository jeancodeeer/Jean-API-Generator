#!/usr/bin/env bash
# Jean API en GitHub Codespaces (CPU).
# Uso:  bash serve.sh {grey|marvel|fenix}
#
# Env:
#   JEAN_API_KEY   (obligatorio) clave Bearer de la API
#   HF_TOKEN       token HF (repo privado de modelos)
#   JEAN_SOURCE    hf (default) | github   (de dónde bajar los GGUF)
#   JEAN_REPO      repo HF de modelos       (default JeanCoder/jean-models)
#   JEAN_GH_REPO   repo GitHub del release  (default jeancodeeer/jean-api)
#   JEAN_GH_TAG    tag del release          (default v0.7-models)
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
GGDIR="${JEAN_GGUF_DIR:-$HOME/gguf}"
mkdir -p "$GGDIR"

# Fenix = Qwen3.5-27B (base publica) + LoRA entrenado de Jean.
FENIX_BASE_REPO="unsloth/Qwen3.5-27B-GGUF"
FENIX_BASE_FILE="Qwen3.5-27B-Q4_K_M.gguf"
FENIX_LORA_FILE="jean-fenix-v0.7.lora.gguf"

if [ "$MODEL" = "fenix" ]; then
  FILE="$FENIX_BASE_FILE"
else
  FILE="jean-${MODEL}-v0.7.Q4_K_M.gguf"
fi
BASE="$(basename "$FILE" .gguf)"

# Contexto: Grey aguanta 16k; 27B en 16 GB no entra.
CTX=8192
[ "$MODEL" = "grey" ] && CTX=16384
[ "$MODEL" = "fenix" ] && CTX=4096

# ---------------------------------------------------------------- llama.cpp
find_server() { find "$HOME/llama" -name llama-server -type f 2>/dev/null | head -1 || true; }

install_llama() {
  echo "[serve] instalando llama.cpp prebuilt (CPU) ..."
  local url
  url=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=3" \
    | grep -o '"browser_download_url": *"[^"]*bin-ubuntu-x64\.tar\.gz"' \
    | head -1 | cut -d'"' -f4)
  [ -n "${url:-}" ] || { echo "no encontre binario ubuntu-x64" >&2; exit 1; }
  mkdir -p "$HOME/llama"
  curl -sL "$url" | tar -xz -C "$HOME/llama"
}

# ---------------------------------------------------------------- descarga
hf_get() {  # hf_get <repo> <archivo> <destino> [token]
  local repo="$1" file="$2" dst="$3" token="${4:-}"
  [ -s "$dst" ] && return 0
  echo "[serve] bajando $file desde $repo ..."
  local auth=()
  [ -n "$token" ] && auth=(-H "Authorization: Bearer $token")
  curl -fL --retry 3 --retry-delay 2 -C - "${auth[@]}" \
    "https://huggingface.co/$repo/resolve/main/$file" -o "$dst.part" \
    && mv "$dst.part" "$dst"
}

download_github() {  # baja partes del release y reconstruye
  [ -s "$GGDIR/$FILE" ] && return 0
  local api="https://api.github.com/repos/$GH_REPO/releases/tags/$GH_TAG"
  local auth=()
  [ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GH_TOKEN")
  echo "[serve] $FILE no esta; bajando partes de $GH_REPO@$GH_TAG ..."
  local tmp="$GGDIR/.parts-$BASE"
  rm -rf "$tmp"; mkdir -p "$tmp"
  local manifest
  manifest=$(curl -sL "${auth[@]}" "$api" \
    | grep -o '"browser_download_url": *"[^"]*'"$BASE"'\.manifest\.json"' \
    | head -1 | cut -d'"' -f4)
  [ -n "${manifest:-}" ] || { echo "no encontre $BASE.manifest.json en el release" >&2; exit 1; }
  curl -sL "${auth[@]}" "$manifest" -o "$tmp/manifest.json"

  python3 - "$tmp/manifest.json" "$api" "$GGDIR/$FILE" <<'PY'
import json, os, sys, urllib.request
man, api, out = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(man))
req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json"})
if os.environ.get("GH_TOKEN"):
    req.add_header("Authorization", "Bearer " + os.environ["GH_TOKEN"])
urls = {a["name"]: a["browser_download_url"] for a in json.load(urllib.request.urlopen(req))["assets"]}
tmpdir = os.path.dirname(man)
with open(out, "wb") as g:
    for p in m["parts"]:
        dst = os.path.join(tmpdir, p["name"])
        if not os.path.exists(dst) or os.path.getsize(dst) != p["bytes"]:
            print(f"[serve]   bajando {p['name']} ({p['bytes']/2**30:.2f} GiB)")
            urllib.request.urlretrieve(urls[p["name"]], dst)
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
  [ "$want" = "$got" ] || { echo "sha256 NO coincide" >&2; rm -f "$GGDIR/$FILE"; exit 1; }
  echo "[serve] sha256 OK"
  rm -rf "$tmp"
}

# ---------------------------------------------------------------- main
BIN=$(find_server)
[ -n "$BIN" ] || { install_llama; BIN=$(find_server); }
[ -n "$BIN" ] || { echo "no pude instalar llama-server" >&2; exit 1; }

THREADS=$(nproc 2>/dev/null || echo 4)
LORA_ARGS=()

if [ "$MODEL" = "fenix" ]; then
  hf_get "$FENIX_BASE_REPO" "$FENIX_BASE_FILE" "$GGDIR/$FENIX_BASE_FILE" ""
  hf_get "$HF_REPO" "$FENIX_LORA_FILE" "$GGDIR/$FENIX_LORA_FILE" "${HF_TOKEN:-}"
  LORA_ARGS=(--lora "$GGDIR/$FENIX_LORA_FILE")
else
  case "$SRC" in
    hf)     hf_get "$HF_REPO" "$FILE" "$GGDIR/$FILE" "${HF_TOKEN:?falta HF_TOKEN}" ;;
    github) download_github ;;
    *) echo "JEAN_SOURCE invalido: $SRC" >&2; exit 1 ;;
  esac
fi

echo "[serve] jean-$MODEL en :$PORT (ctx $CTX, $THREADS hilos)"
exec "$BIN" -m "$GGDIR/$FILE" "${LORA_ARGS[@]}" --host 0.0.0.0 --port "$PORT" \
  --alias "jean-$MODEL" -c "$CTX" --threads "$THREADS" \
  --temp 0.2 --top-p 0.9 --api-key "${JEAN_API_KEY:-}"
