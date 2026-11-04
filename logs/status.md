# status 2026-11-04T12:57:38Z

## memoria
               total        used        free      shared  buff/cache   available
Mem:           15993        3746         209          63       12448       12247
Swap:              0           0           0

## procesos
845 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
851 /home/vscode/llama/llama-b12110/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.004.778 I srv  llama_server: initializing ...
0.00.021.836 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.024.083 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'
0.17.885.932 I cmn          init: llama threadpool init, n_threads = 4
0.22.288.246 I srv    load_model: initializing, n_slots = 4, n_ctx_slot = 16384, kv_unified = 'true'
0.22.383.932 I srv  server_run_i: model loaded
0.22.383.988 I srv  server_on_li: listening on http://0.0.0.0:8888

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.001.756 I srv  llama_server: initializing ...
0.00.019.914 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.022.660 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.00.374.708 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

