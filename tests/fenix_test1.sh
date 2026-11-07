#!/usr/bin/env bash
# fenix_test1.sh — estado del serve fenix-lite + inferencia
tail -2 /tmp/serve-fenix.log | cut -c1-140
free -m | awk '/Mem:/'
pgrep -a llama-server | cut -c1-60
code=$(curl -s -o /tmp/f.json -w '%{http_code}' -m 280 \
  -H "Authorization: Bearer $JEAN_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"jean-fenix-lite","messages":[{"role":"user","content":"Responde solo: fenix-lite-ok"}],"max_tokens":40}' \
  http://127.0.0.1:8890/v1/chat/completions 2>/dev/null)
rc=$?
if [ $rc -ne 0 ]; then code="curl-rc$rc"; fi
echo "inferencia: $code -> $(python3 -c 'import json;print(json.load(open("/tmp/f.json"))["choices"][0]["message"]["content"])' 2>/dev/null || echo '?')"
