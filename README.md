# jean-api — Modelos Jean como API en GitHub Codespaces

API OpenAI-compatible (`/v1/chat/completions`) con llama.cpp CPU.

## Setup (una sola vez)
1. Secrets de Codespaces (github.com → Settings → Codespaces → Secrets):
   - `HF_TOKEN` — tu token HF con acceso a `JeanCoder/jean-models`
   - `JEAN_API_KEY` — la clave Bearer de la API
2. Crear el Codespace en máquina **4 cores / 16 GB** (`basicLinux32gb`).

## Arrancar (cada vez que la necesites)
```bash
bash serve.sh marvel      # o grey / fenix
```
Luego hacer el puerto 8888 **público** (Ports → visibility → Public).

## Consumir
```
POST https://<nombre-codespace>-8888.app.github.dev/v1/chat/completions
Authorization: Bearer <JEAN_API_KEY>
{"model":"jean-marvel","messages":[{"role":"user","content":"hola"}]}
```

## Notas
- Free tier GitHub: 120 core-h/mes → ~30 h con 4 cores (o ~60 h con 2 cores/8 GB, modelo grey).
- El Codespace se apaga solo tras ~30 min sin actividad (configurable en Settings).
- Pesos persistentes en `~/gguf` mientras el Codespace exista; rebuild re-descarga del HF Hub.
