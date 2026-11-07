# -*- coding: utf-8 -*-
"""Mapa fisico del proyecto Jean (leible por graphify: asta parsea este modulo).
Todo lugar donde vive cualquier parte del proyecto. Si una ruta cambia, CAMBIA AQUI."""

PC = {
    "hub_operacion": r"D\jean-work",                                # README/AGENTS/control/kernels
    "control_codespace": r"D\jean-work\jean-api.ps1",
    "clave_api_local": r"D\jean-work\jean_api_key.txt",
    "espejo_repo": r"D\jean-work\codespaces-jean",               # = repo byte a byte
    "kernels_kaggle": r"D\jean-work\kaggle",                     # fenix-hfpub, fenix-lite, fenix-q5
    "archivo_experimentos": r"D\jean-work\archive",
    "generador_local": r"D\jean-work\generator",
    "base_qwen_27b_gguf": r"D\jean-work\fenix-gguf\Qwen3.5-27B-Q4_K_M.gguf",
    "store_ollama": r"D\ollama_models",                            # copia local de grey+marvel v0.7
    "repo_entrenamiento": r"G\LIFE IN DANGER\openjarvis-jean-grey",
    "runlog_evidencia": r"G\LIFE IN DANGER\openjarvis-jean-grey\scripts\kaggle\RUNLOG.md",
    "fuente_llama_cpp": r"G\LIFE IN DANGER\tools\llama.cpp",
    "config_opencode": r"C:\Users\ferna\.config\opencode\opencode.jsonc",
}

CODESPACE = {
    "nombre": "jean-api-5g4g4qjg5r7p377jv",
    "checkout_repo": r"/workspaces/jean-api",
    "gguf_servidos": r"/workspaces/jean-api/gguf",
    "llama_server": r"/home/vscode/llama/llama-b12110/llama-server",
}

URLS = {
    "perfil_github": "https://github.com/jeancodeeer",
    "repo_jean_api": "https://github.com/jeancodeeer/jean-api",
    "repo_librecodigo": "https://github.com/jeancodeeer/librecodigo",
    "repo_kanye_nest": "https://github.com/jeancodeeer/kanye-nest",
    "repo_batch_ia": "https://github.com/jeancodeeer/Batch-IA (privado)",
    "uo_jean": "https://huggingface.co/JeanCoder",
    "hf_modelos": "https://huggingface.co/JeanCoder/jean-models",
    "api_grey": "https://jean-api-5g4g4qjg5r7p377jv-8888.app.github.dev/v1",
    "api_marvel": "https://jean-api-5g4g4qjg5r7p377jv-8889.app.github.dev/v1",
    "api_fenix_lite": "https://jean-api-5g4g4qjg5r7p377jv-8890.app.github.dev/v1",
    "graphify": "https://github.com/Graphify-Labs/graphify"
}

# pesos de cada modelo y donde viven (canonico = HF publico)
MODELOS = {
    "jean-grey Q4_K_M (2.52 GiB)": ["HF jean-models (canonico)", "Ollama store local", "workspace del Codespace"],
    "jean-marvel Q4_K_M (4.36 GiB)": ["HF jean-models (canonico)", "Ollama store local", "workspace del Codespace"],
    "jean-fenix Q4_K_M (15.41 GiB)": ["SOLO HF jean-models (sin copia local)"],
    "jean-fenix Q5_K_M (17.91 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lite-IQ3_M (11.72 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lite-IQ4_XS (14.15 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lora (0.59 GiB)": ["SOLO HF jean-models"],
    "base Qwen3.5-27B-Q4_K_M (15.65 GiB)": [r"D\jean-work\fenix-gguf"],
}
