# status 2026-11-04T22:30:33Z

version: b792c0e docs: urls.txt

## RAM
               total        used        free      shared  buff/cache   available
Mem:           15993        1473         208          60       14718       14519
Swap:              0           0           0

## procesos
126 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
136 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
184 /home/vscode/bin/cloudflared tunnel --url http://localhost:8888 --no-autoupdate
320 /home/vscode/bin/cloudflared tunnel --url http://localhost:8889 --no-autoupdate

- **grey**: https://habits-justice-europe-nice.trycloudflare.com
- **marvel**: https://reduces-shanghai-covers-advanced.trycloudflare.com

## self-test
- :8888 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}
- :8889 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}

## cf-grey.log
2026-11-04T22:27:30Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T22:27:30Z INF |                                                                                     |
2026-11-04T22:27:30Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T22:27:30Z INF +-------------------------------------------------------------------------------------+
2026-11-04T22:27:30Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:30Z INF precheck component="Cloudflare API" details="API is reachable" run_id=240bf302-687f-4630-9812-a5461532e0ae status=pass target=api.cloudflare.com:443
2026-11-04T22:27:30Z INF precheck complete hard_fail=false run_id=240bf302-687f-4630-9812-a5461532e0ae suggested_protocol=quic

## cf-marvel.log
2026-11-04T22:27:36Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T22:27:36Z INF |                                                                                     |
2026-11-04T22:27:36Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T22:27:36Z INF +-------------------------------------------------------------------------------------+
2026-11-04T22:27:36Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region1.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=region2.v2.argotunnel.com
2026-11-04T22:27:36Z INF precheck component="Cloudflare API" details="API is reachable" run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d status=pass target=api.cloudflare.com:443
2026-11-04T22:27:36Z INF precheck complete hard_fail=false run_id=9921fedf-1309-4b73-bd47-72a5e8b0ea8d suggested_protocol=quic

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.004.920 I srv  llama_server: initializing ...
0.00.071.351 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.074.896 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.004.881 I srv  llama_server: initializing ...
0.00.071.312 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.074.857 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.00.414.874 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

