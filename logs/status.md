# status 2026-11-04T13:45:00Z

version: b151b61 autostart: retry tunel + grep fix

## RAM
               total        used        free      shared  buff/cache   available
Mem:           15993        1455         187          57       14755       14538
Swap:              0           0           0

## procesos
126 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
136 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
173 /home/vscode/bin/cloudflared tunnel --url http://localhost:8888 --no-autoupdate
285 /home/vscode/bin/cloudflared tunnel --url http://localhost:8889 --no-autoupdate

- **grey**: https://anaheim-weather-spreading-shadows.trycloudflare.com
- **marvel**: https://restructuring-encourages-zope-rob.trycloudflare.com

## self-test
- :8888 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}
- :8889 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}

## cf-grey.log
2026-11-04T13:42:00Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T13:42:00Z INF |                                                                                     |
2026-11-04T13:42:00Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T13:42:00Z INF +-------------------------------------------------------------------------------------+
2026-11-04T13:42:00Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:00Z INF precheck component="Cloudflare API" details="API is reachable" run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 status=pass target=api.cloudflare.com:443
2026-11-04T13:42:00Z INF precheck complete hard_fail=false run_id=395b7c70-b6c5-4a7d-ac1a-f366eebabd99 suggested_protocol=quic

## cf-marvel.log
2026-11-04T13:42:04Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T13:42:04Z INF |                                                                                     |
2026-11-04T13:42:04Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T13:42:04Z INF +-------------------------------------------------------------------------------------+
2026-11-04T13:42:04Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region1.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=region2.v2.argotunnel.com
2026-11-04T13:42:04Z INF precheck component="Cloudflare API" details="API is reachable" run_id=f56df71a-04bc-492b-8f81-ac76330e873e status=pass target=api.cloudflare.com:443
2026-11-04T13:42:04Z INF precheck complete hard_fail=false run_id=f56df71a-04bc-492b-8f81-ac76330e873e suggested_protocol=quic

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.004.338 I srv  llama_server: initializing ...
0.00.062.075 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.065.284 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.004.321 I srv  llama_server: initializing ...
0.00.062.058 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.065.267 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.00.447.228 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

