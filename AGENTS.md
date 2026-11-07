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

## Comandos rápidos
- PC: `D:\jean-work\jean-api.ps1 start|stop|urls|test|status|fenix-mode|standard-mode`
- dentro del Codespace: `bash tests/test_ctx.sh` (verifica ctx 131072), `bash tests/diag.sh`
- regenerar grafo Graphify: `graphify .` (pip install graphifyy; `--code-only` sin LLM-key)
