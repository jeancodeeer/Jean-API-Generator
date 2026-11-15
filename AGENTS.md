# AGENTS.md — guía para IAs sobre `Jean-API-Generator`

> Si eres una IA/agent (Claude Code, Cursor, Graphify, Copilot...): empieza por
> `README.md` (mapa completo del proyecto). Este archivo solo fija reglas rápidas.

## Qué es
API **compatible con OpenAI y gratis** (`llama.cpp llama-server`) de los modelos
**Jean v0.7** (Grey 2.52 GiB · Marvel 4.36 GiB · Fénix 15.41 GiB). Cada persona la ejecuta
con su cuenta o en su máquina: **Kaggle** (GPU T4 x2 gratis, `kaggle/jean-api.ipynb`),
**cualquier Linux x86_64 o WSL** (`python3 launch.py`), Windows/macOS nativos (`generator/`)
o una VM (`oracle/setup-vm.sh`). No depende de GitHub Codespaces (se retiró en 2026-11).
Pesos: Hugging Face `JeanCoder/jean-models` (público).

## Reglas duras
1. **Ninguna clave/URL privada en archivos**: valores solo por variables de entorno o Secrets
   de Kaggle. Nunca escribas mi usuario a mano en las URLs: derívalo de `GET /user` (una
   `e` de menos en `jeancodeeer` produjo un falso diagnóstico de "repo oculto").
2. **`launch.py` es el único lanzador** (Kaggle lo llama vía `kaggle/launch.py`, que solo lo
   reenvía). No dupliques su lógica en el notebook ni en otros scripts.
3. `serve.sh` es LA fuente única de parámetros del servidor (`-ctk/-ctv q8_0`, contexto por
   `JEAN_CTX`). `generator/` y `oracle/` tienen su propia instalación, pero no otros flags.
4. Puertos: modelos desde 8888 (se saltan los ocupados: en Kaggle el 8888 es de Jupyter),
   router en 8899 (o 9899+ si está ocupado). Pruebas: `python -m unittest tests.test_launch`.
5. Diagnóstico 401/503: el lanzador muestra las últimas líneas del registro del modelo o del
   router que se cae; los registros están en `JEAN_HOME` (`/kaggle/tmp` o `~/.cache/jean-api`).
6. Fénix sin GPU en 16 GB es **inusable** (~100 s/token, verificado): necesita las dos T4 de
   Kaggle o una máquina con ≥ 32 GB.
7. Todo cambio relevante va al `RUNLOG.md` de `openjarvis-jean-grey/scripts/kaggle/`
   (evidencia, no promesas): estado sin tool-output = falso.

## Dónde está TODO (mapa físico + web)
Fuente completa y actualizada: `tools/project_map.py` (parseable por Graphify) y el README.

- **Hub en mi PC**: `D:\jean-work` — espejo del repo en `codespaces-jean\` (nombre antiguo de la
  carpeta), kernels Kaggle en `kaggle\`, experimentos en `archive\`.
- **Pesos de los modelos**: fuente canónica = HF público `https://huggingface.co/JeanCoder/jean-models`
  (los 7 GGUF de Jean). Copias locales: store de Ollama `D:\ollama_models` (grey+marvel, 6.9 GB).
  Peso base Qwen27B: `D:\jean-work\fenix-gguf\` (NO borrar).
- **Entrenamiento**: `G:\LIFE IN DANGER\openjarvis-jean-grey` (datasets/LoRA/persona + RUNLOG en `scripts\kaggle\`).
- **Web**: mi perfil `https://github.com/jeancodeeer` · HF `https://huggingface.co/JeanCoder`.

8. **Router en :8899** (`control/router.py` + `control/control_server.py`): URL única compatible
   con OpenAI para todos los puertos. Nunca cambia de modelo en silencio (503 + lista de
   disponibles). Pruebas: `python tests/test_router.py`. `serve.sh` escribe en
   `/tmp/jean-slot-<puerto>.status` por qué un puerto no arrancó; el router lo muestra.

## Comandos rápidos
- cualquier Linux / WSL: `python3 launch.py` (variables en su docstring: `JEAN_MODELS`, `JEAN_TUNNEL=0`...)
- Kaggle: importar `kaggle/jean-api.ipynb`, GPU T4 x2 + Internet, Run All
- pruebas: `python tests/test_router.py` · `python -m unittest tests.test_launch`
- regenerar grafo Graphify: `graphify .` (pip install graphifyy; `--code-only` sin LLM-key)
