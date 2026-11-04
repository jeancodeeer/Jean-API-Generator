# status 2026-11-04T23:56:20Z

version: 969d5f2 autostart: URLs estables de GitHub + respaldo Cloudflare

## RAM
               total        used        free      shared  buff/cache   available
Mem:           15993        1456         229          56       14711       14536
Swap:              0           0           0

## procesos
127 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
136 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
173 /home/vscode/bin/cloudflared tunnel --url http://localhost:8888 --no-autoupdate
264 /home/vscode/bin/cloudflared tunnel --url http://localhost:8889 --no-autoupdate

## URLs estables (GitHub)
- **grey**: https://jean-api-5g4g4qjg5r7p377jv-8888.app.github.dev/v1
- **marvel**: https://jean-api-5g4g4qjg5r7p377jv-8889.app.github.dev/v1

## URLs de respaldo (Cloudflare)
- **grey**: https://simplified-intelligence-halo-hope.trycloudflare.com
- **marvel**: https://advisor-printer-presence-geometry.trycloudflare.com

## self-test
- :8888 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}
- :8889 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}

## cf-grey.log
2026-11-04T23:53:20Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T23:53:20Z INF |                                                                                     |
2026-11-04T23:53:20Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T23:53:20Z INF +-------------------------------------------------------------------------------------+
2026-11-04T23:53:20Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:20Z INF precheck component="Cloudflare API" details="API is reachable" run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a status=pass target=api.cloudflare.com:443
2026-11-04T23:53:20Z INF precheck complete hard_fail=false run_id=4b6110a1-23d9-40bf-aaf4-6776e78c590a suggested_protocol=quic

## cf-marvel.log
2026-11-04T23:53:25Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T23:53:25Z INF |                                                                                     |
2026-11-04T23:53:25Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T23:53:25Z INF +-------------------------------------------------------------------------------------+
2026-11-04T23:53:25Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region1.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=region2.v2.argotunnel.com
2026-11-04T23:53:25Z INF precheck component="Cloudflare API" details="API is reachable" run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 status=pass target=api.cloudflare.com:443
2026-11-04T23:53:25Z INF precheck complete hard_fail=false run_id=56aea4b9-fd0b-46e2-902e-e5c7c3523750 suggested_protocol=quic

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.004.161 I srv  llama_server: initializing ...
0.00.059.343 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.062.502 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.004.198 I srv  llama_server: initializing ...
0.00.059.381 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.062.541 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.00.373.733 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

