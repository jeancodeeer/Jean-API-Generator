#!/usr/bin/env bash
# Compara las dos formas de bajar un asset de un release PRIVADO.
T="$1"
NAME="jean-marvel-v0.7.Q4_K_M.manifest.json"
API="https://api.github.com/repos/jeancodeeer/jean-api/releases/tags/v0.7-models"

ID=$(curl -s -H "Authorization: Bearer $T" -H 'Accept: application/vnd.github+json' "$API" \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print(next(a['id'] for a in d['assets'] if a['name']=='$NAME'))")
echo "asset id: $ID"

echo "--- A) API asset + Accept: octet-stream ---"
curl -sL -H "Authorization: Bearer $T" -H 'Accept: application/octet-stream' \
  "https://api.github.com/repos/jeancodeeer/jean-api/releases/assets/$ID" \
  -w '\nHTTP=%{http_code} size=%{size_download}\n' | head -c 220
echo
echo "--- B) browser_download_url con token ---"
curl -sL -H "Authorization: Bearer $T" \
  "https://github.com/jeancodeeer/jean-api/releases/download/v0.7-models/$NAME" \
  -w '\nHTTP=%{http_code} size=%{size_download}\n' | head -c 220
echo
