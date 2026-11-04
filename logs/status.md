# status 2026-11-04T13:36:41Z

version: c98cbdf autostart: watchdog + urls.txt

## RAM
               total        used        free      shared  buff/cache   available
Mem:           15993        1402         254          56       14740       14590
Swap:              0           0           0

## procesos
126 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
136 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013

- **grey**: https://api.trycloudflare.com
- **marvel**: https://api.trycloudflare.com

## self-test
- :8888 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}
- :8889 -> {"error":{"message":"Loading model","type":"unavailable_error","code":503}}

## cf-grey.log
2026-11-04T13:33:49Z INF Thank you for trying Cloudflare Tunnel. Doing so, without a Cloudflare account, is a quick way to experiment and try it out. However, be aware that these account-less Tunnels have no uptime guarantee, are subject to the Cloudflare Online Services Terms of Use (https://www.cloudflare.com/website-terms/), and Cloudflare reserves the right to investigate your use of Tunnels for violations of such terms. If you intend to use Tunnels in production you should use a pre-created named tunnel by following: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps
2026-11-04T13:33:49Z INF Requesting new quick Tunnel on trycloudflare.com...
failed to request quick Tunnel: Post "https://api.trycloudflare.com/tunnel": context deadline exceeded (Client.Timeout exceeded while awaiting headers)

## cf-marvel.log
2026-11-04T13:33:49Z INF Thank you for trying Cloudflare Tunnel. Doing so, without a Cloudflare account, is a quick way to experiment and try it out. However, be aware that these account-less Tunnels have no uptime guarantee, are subject to the Cloudflare Online Services Terms of Use (https://www.cloudflare.com/website-terms/), and Cloudflare reserves the right to investigate your use of Tunnels for violations of such terms. If you intend to use Tunnels in production you should use a pre-created named tunnel by following: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps
2026-11-04T13:33:49Z INF Requesting new quick Tunnel on trycloudflare.com...
failed to request quick Tunnel: Post "https://api.trycloudflare.com/tunnel": context deadline exceeded (Client.Timeout exceeded while awaiting headers)

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.006.806 I srv  llama_server: initializing ...
0.01.355.138 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.361.003 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.006.787 I srv  llama_server: initializing ...
0.01.355.119 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.360.983 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.03.319.899 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

