# status 2026-11-04T12:28:57Z

## memoria
               total        used        free      shared  buff/cache   available
Mem:           15993        4247         187          58       11963       11746
Swap:              0           0           0

## procesos
1048 /home/vscode/llama/llama-b12102/llama-server -m /home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8888 --alias jean-grey -c 16384 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013
1053 /home/vscode/llama/llama-b12102/llama-server -m /home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf --host 0.0.0.0 --port 8889 --alias jean-marvel -c 8192 --threads 4 --temp 0.2 --top-p 0.9 --api-key 8e1d99c421aa80c5662d3aaaec4597d02917b9f221279013

## serve-grey.log
[serve] jean-grey en :8888 (ctx 16384, 4 hilos)
0.00.001.150 I srv  llama_server: initializing ...
0.00.014.017 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.016.258 I srv    load_model: loading model '/home/vscode/gguf/jean-grey-v0.7.Q4_K_M.gguf'
0.22.526.062 I cmn          init: llama threadpool init, n_threads = 4
0.23.340.728 I srv    load_model: initializing, n_slots = 4, n_ctx_slot = 16384, kv_unified = 'true'
0.23.380.648 I srv  server_run_i: model loaded
0.23.380.669 I srv  server_on_li: listening on http://0.0.0.0:8888

## serve-marvel.log
[serve] jean-marvel en :8889 (ctx 8192, 4 hilos)
0.00.001.151 I srv  llama_server: initializing ...
0.00.014.014 I cmn  common_param: common_params_print_info: verbosity = 3 (adjust with the `-lv N` CLI arg)
0.00.016.245 I srv    load_model: loading model '/home/vscode/gguf/jean-marvel-v0.7.Q4_K_M.gguf'
0.00.374.123 W load: control-looking token: 128247 '</s>' was not control-type; this is probably a bug in the model. its type will be overridden

