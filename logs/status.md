# status 2026-11-04T12:40:07Z

## memoria
               total        used        free      shared  buff/cache   available
Mem:           15993        1401        5714          56        9281       14592
Swap:              0           0           0

## procesos
106 /home/vscode/llama/llama-b12102/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
115 /home/vscode/llama/llama-b12102/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.049.032 I srv  llama_server: initializing ...
0.01.169.656 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.173.467 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.049.015 I srv  llama_server: initializing ...
0.01.172.274 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.01.174.802 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.02.545.386 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

