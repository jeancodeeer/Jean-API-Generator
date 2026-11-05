# Jean API Generator

Generador de APIs compatibles con OpenAI para los modelos **Jean v0.7**
(Grey, Marvel, Fenix). Todo local, nada de claves ni URLs en repos.

## Requisitos

- Windows 10+ con PowerShell 5.1+ (viene de serie)
- `curl.exe` (incluido en Windows 10+)
- Conexión a internet (solo para descargar los modelos la primera vez)

## Uso

```powershell
# API de Grey (clave auto-generada, puerto 8888)
.\jean-api-generator.ps1 -Model grey

# API de Marvel con clave propia
.\jean-api-generator.ps1 -Model marvel -Port 8889 -ApiKey "mi-clave"

# API de Fenix — SOLO en máquinas con >= 32 GB RAM (archivo único, 17.7 GB)
.\jean-api-generator.ps1 -Model fenix

# Ver qué APIs están corriendo / detener una
.\jean-api-generator.ps1 -Status
.\jean-api-generator.ps1 -Stop -Port 8888
```

## Qué hace

1. Descarga el GGUF del repo **público** `JeanCoder/jean-models` en
   HuggingFace (con resume, cacheado en `gguf/`). No pide ningún token.
2. Busca un `llama-server.exe` en el PC; si no existe, descarga el release
   oficial win-cpu de llama.cpp.
3. Lanza el servidor **solo en `127.0.0.1`** con prioridad baja.
4. Genera una **API key aleatoria propia de esa instancia** (si no pasaste
   `-ApiKey`) y la guarda en `key-<puerto>.txt` — que nunca se commitea.

## Modelos

| modelo | tamaño | contexto | puerto | RAM |
|---|---|---|---|---|
| `grey` | 2.52 GiB | 16k | 8888 | ~4 GB |
| `marvel` | 4.06 GiB | 8k | 8889 | ~6 GB |
| `fenix` | ~17.7 GB | 4k | 8890 | **≥ 32 GB** |

## API

```bash
curl http://127.0.0.1:8888/v1/chat/completions \
  -H "Authorization: Bearer <clave>" -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"hola"}]}'
```

## Privacidad

- Este directorio entero va en `.gitignore` parcial (`gguf/`, `down/`,
  `logs/`, `key-*.txt`): modelos y claves no se suben a ningún repo.
- La API escucha solo en localhost; nada queda expuesto a la red.
