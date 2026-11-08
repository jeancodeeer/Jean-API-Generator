# -*- coding: utf-8 -*-
"""Mapa fisico del proyecto Jean v0.7.

Cada ubicacion es una funcion documentada: graphify las parsea (nodos
autodescriptivos) y cualquier IA que lea este archivo obtiene TODO el mapa.
Si una ruta cambia, se edita SOLO aqui (y el README §6).
"""
OWNER = "".join(chr(c) for c in (106, 101, 97, 110, 99, 111, 100, 101, 101, 101, 114))  # dueno de github (3 e)

def hub_operacion():
    """Hub del proyecto en el PC: README.md, AGENTS.md, jean-api.ps1, push_all.ps1, key"""
    return r"D:\jean-work"

def espejo_repo():
    """Espejo byte-a-byte del repo de github (verificado con blob-sha 28/28)"""
    return r"D:\jean-work\codespaces-jean"

def base_qwen_gguf():
    """PESO BASE del entrenamiento: Qwen3.5-27B-Q4_K_M.gguf (~15.7 GB), NO borrar sin autorizacion"""
    return r"D:\jean-work\fenix-gguf\Qwen3.5-27B-Q4_K_M.gguf"

def store_ollama():
    """Copias LOCALES de los pesos Grey+Marvel v0.7 en Ollama (9 blobs, 6.9 GB)"""
    return r"D:\ollama_models"

def repo_entrenamiento():
    """REPO DE ENTRENAMIENTO: datasets, LoRA, codigo de entrenamiento, models/, persona/, data/"""
    return r"G:\LIFE IN DANGER\openjarvis-jean-grey"

def runlog_evidencia():
    """RUNLOG: registro cronologico de evidencia del entrenamiento y del pipeline"""
    return r"G:\LIFE IN DANGER\openjarvis-jean-grey\scripts\kaggle\RUNLOG.md"

def fuente_llama_cpp():
    """Fuente de llama.cpp (los binarios se compilan de ahi; D:/jean-work/llama-build fue borrado)"""
    return r"G:\LIFE IN DANGER\tools\llama.cpp"

def kernels_kaggle():
    """Kernels CPU de Kaggle (fenix-hfpub v9, fenix-q5, fenix-lite) + logs out4..out9"""
    return r"D:\jean-work\kaggle"

def archivo_experimentos():
    """Experimentos cerrados: hf-spaces, lightning-jean, modal-jean, eval-out, publish_models"""
    return r"D:\jean-work\archive"

def config_opencode():
    """Config de OpenCode en el PC del usuario (providers jean-grey-api y jean-marvel-api)"""
    return r"C:\Users\ferna\.config\opencode\opencode.jsonc"

def github_repo():
    """Repositorio principal del servicio/API (Readme completo + grafo graphify-out/)"""
    return f"https://github.com/{OWNER}/jean-api"

def github_perfil():
    """Perfil GitHub del dueno (repos: jean-api, librecodigo, kanye-nest, Batch-IA privat)"""
    return f"https://github.com/{OWNER}"

def hf_modelos():
    """FUENTE CANONICA de los pesos: repositorio publico con los 7 GGUF (HTTP 200 anonimo)"""
    return "https://huggingface.co/JeanCoder/jean-models"

def hf_perfil():
    """Perfil org del dueno en HF"""
    return "https://huggingface.co/JeanCoder"

def api_grey():
    """API viva de Jean Grey (OpenAI-compatible, contexto 131072, Bearer JEAN_API_KEY)"""
    return "https://jean-api-5g4g4qjg5r7p377jv-8888.app.github.dev/v1"

def api_marvel():
    """API viva de Jean Marvel (OpenAI-compatible, contexto 131072)"""
    return "https://jean-api-5g4g4qjg5r7p377jv-8889.app.github.dev/v1"

def graphify_upstream():
    """Proyecto Graphify (genera graphify-out/: GRAPH_REPORT.md + graph.json + graph.html)"""
    return "https://github.com/Graphify-Labs/graphify"

# --- tabla rapida: donde vive cada peso (referencia cruzada) ---
PESOS = {
    "jean-grey Q4_K_M (2.52 GiB)": ["HF jean-models (canonico)", "Ollama store local", "workspace Codespace"],
    "jean-marvel Q4_K_M (4.36 GiB)": ["HF jean-models (canonico)", "Ollama store local", "workspace Codespace"],
    "jean-fenix Q4_K_M (15.41 GiB)": ["SOLO HF jean-models (sin copia local)"],
    "jean-fenix Q5_K_M (17.91 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lite-IQ3_M (11.72 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lite-IQ4_XS (14.15 GiB)": ["SOLO HF jean-models"],
    "jean-fenix lora (0.59 GiB)": ["SOLO HF jean-models"],
    "base Qwen3.5-27B-Q4_K_M (15.65 GiB)": [r"D:\jean-work\fenix-gguf"],
}
