#!/usr/bin/env bash
# diag.sh — que paso en el boot del codespace
echo "=== logs de serve ==="
for f in /tmp/serve-grey.log /tmp/serve-marvel.log /tmp/autostart-fenix.log; do
  [ -f "$f" ] && { echo "== $f =="; tail -4 "$f" | cut -c1-160; }
done
echo "=== gguf ==="
ls -la /workspaces/jean-api/gguf/ 2>/dev/null | tail -4
echo "=== env ==="
printf 'JEAN_API_KEY len=%s\n' "${#JEAN_API_KEY}"
printf 'JEAN_SOURCE=%s JEAN_GGUF_DIR=%s\n' "${JEAN_SOURCE:-}" "${JEAN_GGUF_DIR:-}"
echo "=== procesos ==="
pgrep -a llama-server | cut -c1-80 || echo "(ninguno)"
echo "=== .jean-mode ==="
cat /workspaces/jean-api/.jean-mode 2>/dev/null || echo standard
