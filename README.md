# jean-api — Jean v0.7

Modelos de código **Jean v0.7** (Grey / Marvel / Fenix), derivados de la familia
Qwen3.5 y publicados en HuggingFace **para todo el mundo**.

Este repo **no aloja ninguna API ni reparte claves**: es un **generador de APIs
por terminal**. Cada persona corre el generador en su máquina, descarga los
modelos del repo público de HF y levanta su propia API OpenAI-compatible en
`127.0.0.1` con una clave que **se genera en su PC** (nada compartido, nada en
GitHub).

## Modelos (HuggingFace público — sin token)

| modelo | archivo | tamaño | contexto | base |
|---|---|---|---|---|
| `jean-grey` | `jean-grey-v0.7.Q4_K_M.gguf` | 2.52 GiB | 16k | Qwen3.5-4B |
| `jean-marvel` | `jean-marvel-v0.7.Q4_K_M.gguf` | 4.06 GiB | 8k | Qwen3.5-7B |
| `jean-fenix` | `jean-fenix-v0.7.Q4_K_M.gguf` | ~17.7 GB | 4k | Qwen3.5-27B (mergeado, archivo único) |

Repo: [`JeanCoder/jean-models`](https://huggingface.co/JeanCoder/jean-models)
(la base de Fenix viene de `unsloth/Qwen3.5-27B-GGUF`; existe además
`jean-fenix-v0.7.lora.gguf`, 0.59 GiB, para el modo ligero base+LoRA).

```bash
# verificación de integridad (todos los GGUF tienen su sha256 en el RUNLOG)
curl -sL https://huggingface.co/JeanCoder/jean-models/resolve/main/jean-grey-v0.7.Q4_K_M.gguf -o grey.gguf
```

## Generador de APIs (la vía recomendada)

En Windows (PowerShell 5.1+), con `curl.exe` disponible:

```powershell
.\generator\jean-api-generator.ps1 -Model grey          # clave auto-generada
.\generator\jean-api-generator.ps1 -Model marvel -Port 8889 -ApiKey "mi-clave"
.\generator\jean-api-generator.ps1 -Status              # qué APIs hay corriendo
.\generator\jean-api-generator.ps1 -Stop -Port 8888     # detener una
```

El generador:
- descarga el GGUF desde HF público (con resume), cacheándolo en `generator/gguf/`
- busca un `llama-server.exe` local; si no hay, baja el release oficial win-cpu
- lanza el servidor **solo en 127.0.0.1** con prioridad baja (no secuestra el PC)
- genera una **API key aleatoria propia de esa instancia** y la guarda en `key-<puerto>.txt`
- no pide ningún token: el repo de modelos es público

Salida típica:

```
=== API Jean-grey LISTA ===
  URL     : http://127.0.0.1:8888/v1
  API key : 8dRw3...xkQ   (guardada en key-8888.txt)
```

Prueba rápida:

```bash
curl http://127.0.0.1:8888/v1/chat/completions \
  -H "Authorization: Bearer <clave>" -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"hola"}]}'
```

## Requisitos por modelo

| modelo | RAM mínima | notas |
|---|---|---|
| grey (4B) | ~4 GB | corre cómodo en laptops |
| marvel (7B) | ~6 GB | |
| fenix (27B) | **≥ 32 GB** | o el modo `-Lora` (base pública + 0.6 GiB de adapter); aún así 27B |

## Espejo y modo Codespace (opcional)

- El release `v0.7-models` de este repo replica los pesos en trozos < 2 GiB con
  manifest sha256 (reconstruir: `cat *.part* > modelo.gguf`).
- `serve.sh` + `.devcontainer/` permiten servir los modelos desde un Codespace
  propio (grey+marvel simultáneos en 4c/16 GB free tier). En ese caso las URLs
  y la clave **son de quien lo despliegue**: este repo no publica ninguna.
- `check_lora.py` / `gguf_info.py`: utilidades para validar compatibilidad
  adapter↔base leyendo solo cabeceras GGUF.
