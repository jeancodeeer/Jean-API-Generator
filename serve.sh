#!/usr/bin/env bash
# Jean API en GitHub Codespaces (CPU).
# Uso:  bash serve.sh {grey|marvel|fenix}
#
# Env:
#   JEAN_API_KEY   (obligatorio) clave Bearer de la API
#   HF_TOKEN       token HF (repo privado de modelos)
#   JEAN_SOURCE    hf (default) | github   (de dónde bajar los GGUF)
#   JEAN_REPO      repo HF de modelos       (default JeanCoder/jean-models)
#   JEAN_GH_REPO   repo GitHub del release  (default jeancodeeeer/jean-api)
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
GH_REPO="${JEAN_GH_REPO:-jeancodeeeer/jean-api}"
GH_TAG="${JEAN_GH_TAG:-v0.7-models}"
HF_REPO="${JEAN_REPO:-JeanCoder/jean-models}"
GGDIR="${JEAN_GGUF_DIR:-$HOME/gguf}"
mkdir -p "$GGDIR"

# Fenix = Qwen3.5-27B (base publica) + LoRA entrenado de Jean.
FENIX_BASE_REPO="unsloth/Qwen3.5-27B-GGUF"
FENIX_BASE_FILE="Qwen3.5-27B-Q4_K_M.gguf"
FENIX_LORA_FILE="jean-fenix-v0.7.lora.gguf"

if [ "$MODEL" = "fenix" ] && [ "${FENIX_LORA_MODE:-0}" != "1" ]; then
  # archivo UNICO publico (mergeado, 15.4 GiB)
  FILE="jean-fenix-v0.7.Q4_K_M.gguf"
elif [ "$MODEL" = "fenix" ]; then
  FILE="$FENIX_BASE_FILE"
else
  FILE="jean-${MODEL}-v0.7.Q4_K_M.gguf"
fi
BASE="$(basename "$FILE" .gguf)"

# Contexto: 128k con KV q8_0 (verificado en vivo: ambos a la vez, 3.7 GB
# libres en el codespace de 16 GB). Fenix: FENIX_CTX configurable; el lite
# en 16 GB debe bajarlo (4096-8192).
CTX=131072
[ "$MODEL" = "fenix" ] && CTX="${FENIX_CTX:-131072}"

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

download_github() {  # baja partes del release y reconstruye (repo privado)
  [ -s "$GGDIR/$FILE" ] && return 0
  echo "[serve] $FILE no esta; bajando de $GH_REPO@$GH_TAG ..."
  python3 - "$GH_REPO" "$GH_TAG" "$BASE" "$GGDIR/$FILE" <<'PY'
import hashlib, json, os, subprocess, sys

repo, tag, base, out = sys.argv[1:5]
token = os.environ.get("GH_TOKEN", "")
hdr_json = ["-H", "Accept: application/vnd.github+json"]
hdr_bin = ["-H", "Accept: application/octet-stream"]
if token:
    auth = ["-H", f"Authorization: Bearer {token}"]
    hdr_json += auth
    hdr_bin += auth

# En repos privados browser_download_url da 404: hay que usar la API de assets
# (Accept: octet-stream) y dejar que curl siga el redirect firmado.
def api_json(url):
    return json.loads(subprocess.check_output(["curl", "-fsSL", *hdr_json, url]))

rel = api_json(f"https://api.github.com/repos/{repo}/releases/tags/{tag}")
assets = {a["name"]: a for a in rel["assets"]}
man = assets.get(base + ".manifest.json")
if not man:
    sys.exit(f"no encontre {base}.manifest.json en el release")
m = json.loads(subprocess.check_output(["curl", "-fsSL", *hdr_bin, man["url"]]))

h = hashlib.sha256()
with open(out, "wb") as g:
    for p in m["parts"]:
        a = assets.get(p["name"])
        if not a:
            sys.exit(f"falta el asset {p['name']}")
        print(f"[serve]   bajando {p['name']} ({p['bytes']/2**30:.2f} GiB)", flush=True)
        subprocess.run(["curl", "-fsSL", "--retry", "3", *hdr_bin, a["url"]],
                       stdout=g, check=True)
with open(out, "rb") as f:
    for chunk in iter(lambda: f.read(8 << 20), b""):
        h.update(chunk)

got = h.hexdigest()
print(f"[serve] sha256 {got}")
if got != m["sha256"]:
    os.remove(out)
    sys.exit(f"[serve] sha256 NO coincide (esperado {m['sha256']})")
print("[serve] sha256 OK")
PY
}

# ---------------------------------------------------------------- main
BIN=$(find_server)
[ -n "$BIN" ] || { install_llama; BIN=$(find_server); }
[ -n "$BIN" ] || { echo "no pude instalar llama-server" >&2; exit 1; }

THREADS=$(nproc 2>/dev/null || echo 4)
LORA_ARGS=()

if [ "$MODEL" = "fenix" ]; then
  if [ "${FENIX_LORA_MODE:-0}" = "1" ]; then
    # modo ligero: base publica + LoRA (equivale al unificado)
    hf_get "$FENIX_BASE_REPO" "$FENIX_BASE_FILE" "$GGDIR/$FENIX_BASE_FILE" ""
    hf_get "$HF_REPO" "$FENIX_LORA_FILE" "$GGDIR/$FENIX_LORA_FILE" ""
    LORA_ARGS=(--lora "$GGDIR/$FENIX_LORA_FILE")
  else
    FILE="${FENIX_FILE:-jean-fenix-v0.7.Q4_K_M.gguf}"
    BASE="$(basename "$FILE" .gguf)"
    hf_get "$HF_REPO" "$FILE" "$GGDIR/$FILE" ""
  fi
else
  case "$SRC" in
    hf)     hf_get "$HF_REPO" "$FILE" "$GGDIR/$FILE" "${HF_TOKEN:?falta HF_TOKEN}" ;;
    github) download_github ;;
    *) echo "JEAN_SOURCE invalido: $SRC" >&2; exit 1 ;;
  esac
fi

echo "[serve] jean-$MODEL en :$PORT (ctx $CTX, $THREADS hilos)"
exec "$BIN" -m "$GGDIR/$FILE" "${LORA_ARGS[@]}" --host 0.0.0.0 --port "$PORT" \
  --alias "${FENIX_ALIAS:-jean-$MODEL}" -c "$CTX" --threads "$THREADS" \
  -ctk q8_0 -ctv q8_0 \
  --temp 0.2 --top-p 0.9 --api-key "${JEAN_API_KEY:-}"
