#!/usr/bin/env bash
# Jean API en GitHub Codespaces (CPU).
# Uso:  bash serve.sh {grey|marvel|fenix|custom}
#   custom: GGUF cargado por control/control_server.py; usa CUSTOM_FILE (ruta dentro de gguf/),
#           CUSTOM_ALIAS y CUSTOM_CTX (default 16384). No descarga nada.
#
# Env:
#   JEAN_API_KEY   (obligatorio) clave Bearer de la API; sin ella no arranca
#   FENIX_FILE     GGUF de Fenix (default: el mas grande publicado que cabe en la RAM)
#   HF_TOKEN       token HF (opcional: JeanCoder/jean-models es publico)
#   JEAN_SOURCE    hf (default) | github   (de dónde bajar los GGUF)
#   JEAN_REPO      repo HF de modelos       (default JeanCoder/jean-models)
#   JEAN_GH_REPO   repo GitHub del release  (default jeancodeeer/jean-api)
#   JEAN_GH_TAG    tag del release          (default v0.7-models)
#   PORT           puerto (default 8888)
set -euo pipefail

MODEL="${1:-grey}"
case "$MODEL" in
  grey|marvel|fenix|custom) ;;
  *) echo "uso: bash serve.sh {grey|marvel|fenix|custom}" >&2; exit 1 ;;
esac

PORT="${PORT:-8888}"
# Motivo de fallo para el router (/v1/models lo muestra en "unavailable"). Se borra al arrancar bien.
STATUS_FILE="/tmp/jean-slot-${PORT}.status"
fail() { echo "[serve] $*" >&2; echo "$*" > "$STATUS_FILE"; exit 1; }

# Sin clave, llama-server serviria el puerto PUBLICO sin autenticacion: nunca.
if [ -z "${JEAN_API_KEY:-}" ] && [ "${JEAN_ALLOW_NO_KEY:-0}" != "1" ]; then
  fail "falta JEAN_API_KEY: no sirvo un puerto sin clave (JEAN_ALLOW_NO_KEY=1 solo para pruebas locales)"
fi
SRC="${JEAN_SOURCE:-hf}"
GH_REPO="${JEAN_GH_REPO:-jeancodeeer/jean-api}"
GH_TAG="${JEAN_GH_TAG:-v0.7-models}"
HF_REPO="${JEAN_REPO:-JeanCoder/jean-models}"
# los GGUF viven en gguf/ del workspace (persiste entre rebuilds); nunca en $HOME,
# o un relanzamiento vuelve a descargarlos y llena el disco
GGDIR="${JEAN_GGUF_DIR:-$(cd "$(dirname "$0")" && pwd)/gguf}"
mkdir -p "$GGDIR"

# Fenix = Qwen3.5-27B (base publica) + LoRA entrenado de Jean.
FENIX_BASE_REPO="unsloth/Qwen3.5-27B-GGUF"
FENIX_BASE_FILE="Qwen3.5-27B-Q4_K_M.gguf"
FENIX_LORA_FILE="jean-fenix-v0.7.lora.gguf"

if [ "$MODEL" = "custom" ]; then
  FILE="${CUSTOM_FILE:?custom necesita CUSTOM_FILE}"
  case "$FILE" in /*|*..*) echo "CUSTOM_FILE debe ser una ruta relativa dentro de gguf/" >&2; exit 1 ;; esac
elif [ "$MODEL" = "fenix" ] && [ "${FENIX_LORA_MODE:-0}" != "1" ]; then
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
[ "$MODEL" = "custom" ] && CTX="${CUSTOM_CTX:-16384}"

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

# Fenix: elige el GGUF de Fenix publicado en HF que mejor cabe en la RAM de esta maquina
# (deja ~3 GB para el KV y el sistema). Nuevas versiones (v0.8 IQ2_M...) se usan solas al publicarse.
fenix_pick() {
  local mem_kb="${JEAN_MEM_KB:-$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)}"
  curl -fsSL --max-time 30 "https://huggingface.co/api/models/$HF_REPO/tree/main" 2>/dev/null     | python3 -c '
import json, sys
mem, status = int(sys.argv[1]) * 1024, sys.argv[2]
def fail(msg):
    open(status, "w").write(msg + chr(10))
    sys.exit("[serve] " + msg)
try:
    tree = json.load(sys.stdin)
except ValueError:
    fail("no pude leer la lista de modelos de Hugging Face (sin red?)")
files = [(f.get("lfs", {}).get("size") or f.get("size", 0), f["path"]) for f in tree
         if f.get("type") == "file" and f["path"].startswith("jean-fenix") and f["path"].endswith(".gguf")
         and ".lora." not in f["path"]]
if not files:
    fail("no hay ningun GGUF de Fenix publicado en el repo de modelos")
fit = [f for f in files if f[0] + 3 * 2**30 <= mem]
if not fit:
    small = min(files)
    fail(f"Fenix no cabe en esta maquina: el archivo mas pequeno ({small[1]}) pesa "
         f"{small[0] / 2**30:.1f} GB y hay {mem / 2**30:.0f} GB de RAM. Usa una maquina de 32 GB.")
fit.sort(key=lambda f: (f[1].split(".")[0], f[0]))   # version mas nueva y, dentro de ella, el mas grande
print(fit[-1][1])
' "$mem_kb" "$STATUS_FILE"
}

# ---------------------------------------------------------------- main
BIN=$(find_server)
[ -n "$BIN" ] || { install_llama; BIN=$(find_server); }
[ -n "$BIN" ] || fail "no pude instalar llama-server"

THREADS=$(nproc 2>/dev/null || echo 4)
LORA_ARGS=()

if [ "$MODEL" = "custom" ]; then
  [ -s "$GGDIR/$FILE" ] || fail "no existe gguf/$FILE"
elif [ "$MODEL" = "fenix" ]; then
  if [ "${FENIX_LORA_MODE:-0}" = "1" ]; then
    # modo ligero: base publica + LoRA (equivale al unificado)
    hf_get "$FENIX_BASE_REPO" "$FENIX_BASE_FILE" "$GGDIR/$FENIX_BASE_FILE" ""
    hf_get "$HF_REPO" "$FENIX_LORA_FILE" "$GGDIR/$FENIX_LORA_FILE" ""
    LORA_ARGS=(--lora "$GGDIR/$FENIX_LORA_FILE")
  else
    FILE="${FENIX_FILE:-}"
    if [ -z "$FILE" ]; then
      FILE=$(fenix_pick) || exit 1
      echo "[serve] fenix: $FILE (el mas grande que cabe en esta maquina)"
    fi
    BASE="$(basename "$FILE" .gguf)"
    hf_get "$HF_REPO" "$FILE" "$GGDIR/$FILE" "" || fail "no pude bajar $FILE de $HF_REPO"
  fi
else
  case "$SRC" in
    hf)     hf_get "$HF_REPO" "$FILE" "$GGDIR/$FILE" "${HF_TOKEN:-}" ;;
    github) download_github ;;
    *) echo "JEAN_SOURCE invalido: $SRC" >&2; exit 1 ;;
  esac
fi

ALIAS="${FENIX_ALIAS:-jean-$MODEL}"
[ "$MODEL" = "custom" ] && ALIAS="${CUSTOM_ALIAS:-custom}"
echo "[serve] $ALIAS en :$PORT (ctx $CTX, $THREADS hilos)"
rm -f "$STATUS_FILE"
# La clave va por entorno (LLAMA_API_KEY, que llama-server lee), NO como argumento: un argumento
# se ve en la lista de procesos (ps, pgrep -af) y acababa copiado en ~/logs/status.md.
export LLAMA_API_KEY="${JEAN_API_KEY:-}"
exec "$BIN" -m "$GGDIR/$FILE" "${LORA_ARGS[@]}" --host 0.0.0.0 --port "$PORT" \
  --alias "$ALIAS" -c "$CTX" --threads "$THREADS" \
  -ctk q8_0 -ctv q8_0 \
  --temp 0.2 --top-p 0.9
