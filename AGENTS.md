# AGENTS.md — guía para IAs sobre el repo `jean-api`

> Si eres una IA/agent (Claude Code, Cursor, Graphify, Copilot...): empieza por
> `README.md` (mapa completo del proyecto). Este archivo solo fija reglas rápidas.

## Qué es
Servicio **OpenAI-compatible gratis** (`llama.cpp llama-server`) de los modelos
**Jean v0.7** (Grey 2.52 GiB en :8888 · Marvel 4.36 GiB en :8889 · Fénix-lite :8890 en
modo `fenix`), servidos desde un GitHub Codespace (4c/16GB) a **contexto 131072 con KV
q8_0**. Base del pipeline QA: Hugging Face `JeanCoder/jean-models` (público).

## Reglas duras
1. **Ninguna clave/URL privada en archivos**: valores solo por env vars/secrets.
   Para secretos del Codespace usa `tools/set_secrets.py` (toda entrada via
   entorno). Nunca hardcodear el owner de URLs: derivarlo de `GET /user` (una
   `e` de menos en `jeancodeeer` produjo un falso diagnóstico de "repo oculto").
2. **No tocar los parámetros de serve.sh** (`-c 131072`, `-ctk/-ctv q8_0`) sin
   re-verificar RAM: en 16 GB solo 2 modelos caben a la vez (verificado en vivo).
3. `serve.sh` es LA fuente única de parámetros del servidor. `generator/` lo genera
   (RAM-aware: ≥20 GB→128k, ≥12 GB→64k, else 8k); no duplicar lógica.
4. El **modo** del Codespace vive en `.jean-mode` (`standard`|`fenix`) y los **GGUF**
   en `gguf/` (workspace, persiste entre rebuilds). No moverlos de ahí.
5. Diagnóstico 401/503: primero `tests/diag.sh` dentro del Codespace (procesos, logs,
   disco), потом `.\jean-api.ps1 start|test` desde el PC. Un 401 de cuerpo vacío casi
   siempre es el proxy de GitHub porque no hay servidor en el puerto.
6. Fénix en 16 GB es **inusable** (~100 s/token, verificado): no reintentes hacia el
   Codespace; el camino es una máquina ≥32 GB o un kernel CPU de Kaggle (30 GB).
7. Todo cambio relevante va al `RUNLOG.md` de `openjarvis-jean-grey/scripts/kaggle/`
   (evidencia, no promesas): estado sin tool-output = falso.

## Dónde está TODO (mapa físico + web)
Fuente completa y actualizada: `tools/project_map.py` (parseable por Graphify) y README §6.

- **Hub en el PC**: `D:\jean-work` — README/AGENTS/`jean-api.ps1`/`push_all.ps1`/`jean_api_key.txt`,
  espejo del repo en `codespaces-jean\`, kernels Kaggle en `kaggle\`, experimentos en `archive\`.
- **Pesos de los modelos**: fuente canónica = HF público `https://huggingface.co/JeanCoder/jean-models`
  (los 7 GGUF de Jean). Copias locales: store de Ollama `D:\ollama_models` (grey+marvel, 6.9 GB) y
  `gguf/` del workspace del Codespace. Peso base Qwen27B: `D:\jean-work\fenix-gguf\` (NO borrar).
- **Entrenamiento**: `G:\LIFE IN DANGER\openjarvis-jean-grey` (datasets/LoRA/persona + RUNLOG en `scripts\kaggle\`).
- **Web**: perfil `https://github.com/jeancodeeer` · repos `jean-api`, `librecodigo`, `kanye-nest` ·
  HF `https://huggingface.co/JeanCoder` · APIs vivas (Grey :8888, Marvel :8889, Fénix-lite :8890 en modo fenix).

8. **Router en :8899** (`control/router.py`): URL única OpenAI-compatible para todos los puertos.
   Nunca cambia de modelo en silencio (503 + lista de disponibles). Pruebas: `python tests/test_router.py`.
   `serve.sh` escribe en `/tmp/jean-slot-<puerto>.status` por qué un puerto no arrancó; el router lo muestra.

## Comandos rápidos
- PC: `D:\jean-work\jean-api.ps1 start|stop|urls|test|status|fenix-mode|standard-mode`
- dentro del Codespace: `bash tests/test_ctx.sh` (verifica ctx 131072), `bash tests/diag.sh`
- regenerar grafo Graphify: `graphify .` (pip install graphifyy; `--code-only` sin LLM-key)
