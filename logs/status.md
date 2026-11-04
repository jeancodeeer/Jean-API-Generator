# status 2026-11-04T13:10:06Z

version: 06a87e3 autostart: version en status

## RAM
               total        used        free      shared  buff/cache   available
Mem:           15993        4321         234          58       11843       11672
Swap:              0           0           0

## procesos
714 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
719 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
765 /home/vscode/bin/cloudflared tunnel --url http://localhost:8888 --no-autoupdate
771 /home/vscode/bin/cloudflared tunnel --url http://localhost:8889 --no-autoupdate

- **grey**: https://minerals-carroll-spyware-nova.trycloudflare.com
- **marvel**: https://soap-estate-handling-settle.trycloudflare.com

## self-test
- :8888 -> {"models":[{"name":"jean-grey","model":"jean-grey","modified_at":"","size":"","digest":"","type":"model","description":"","tags":[""],"capabilities":["completion"],"parameters":"","details":{"parent_m
- :8889 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}

## cf-install.log
[cf] descargando cloudflared 2026-11-04T13:09:30Z
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 38.4M  100 38.4M    0     0  94.8M      0 --:--:-- --:--:-- --:--:-- 94.8M
[cf] descarga rc=0
cloudflared version 2026.10.7 (built 2026-10-30-17:05 UTC)

## cf-grey.log
2026-11-04T13:09:50Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T13:09:50Z INF |                                                                                     |
2026-11-04T13:09:50Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T13:09:50Z INF +-------------------------------------------------------------------------------------+
2026-11-04T13:09:50Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:50Z INF precheck component="Cloudflare API" details="API is reachable" run_id=15224c80-94d6-46d2-830a-0985a36952a8 status=pass target=api.cloudflare.com:443
2026-11-04T13:09:50Z INF precheck complete hard_fail=false run_id=15224c80-94d6-46d2-830a-0985a36952a8 suggested_protocol=quic

## cf-marvel.log
2026-11-04T13:09:48Z INF |  Cloudflare API    api.cloudflare.com:443     PASS    API is reachable              |
2026-11-04T13:09:48Z INF |                                                                                     |
2026-11-04T13:09:48Z INF |  SUMMARY: Environment is healthy. cloudflared will use 'quic' as primary protocol.  |
2026-11-04T13:09:48Z INF +-------------------------------------------------------------------------------------+
2026-11-04T13:09:48Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="DNS Resolution" details="DNS Resolved successfully" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="UDP Connectivity" details="QUIC connection successful" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region1.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="TCP Connectivity" details="HTTP/2 connection successful" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=region2.v2.argotunnel.com
2026-11-04T13:09:48Z INF precheck component="Cloudflare API" details="API is reachable" run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 status=pass target=api.cloudflare.com:443
2026-11-04T13:09:48Z INF precheck complete hard_fail=false run_id=96a4d9a2-fc63-410e-a582-a4fec768f4a7 suggested_protocol=quic

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.001.573 I srv  llama_server: initializing ...
0.01.655.080 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.657.838 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'
0.30.458.292 I cmn          init: llama threadpool init, n_threads = 4
0.31.398.962 I srv    load_model: initializing, n_slots = 4, n_ctx_slot = 16384, kv_unified = 'true'
0.31.448.403 I srv  server_run_i: model loaded
0.31.448.425 I srv  server_on_li: listening on http://0.0.0.0:8888

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.001.575 I srv  llama_server: initializing ...
0.01.655.079 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.658.199 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.04.445.701 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

