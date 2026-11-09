<div align="center">

<img src="assets/social-preview.svg" alt="JEANCODE-API — API gratuita compatible con OpenAI para los modelos GGUF Jean, servida con llama.cpp en GitHub Codespaces" width="100%">

<br>

[![MODELOS](https://img.shields.io/badge/MODELOS-JEANCODER%2FJEAN--MODELS-ffffff?style=for-the-badge&labelColor=000000)](https://huggingface.co/JeanCoder/jean-models)
[![MOTOR](https://img.shields.io/badge/MOTOR-LLAMA.CPP-ffffff?style=for-the-badge&labelColor=000000)](https://github.com/ggml-org/llama.cpp)
![API](https://img.shields.io/badge/API-COMPATIBLE_OPENAI-ffffff?style=for-the-badge&labelColor=000000)
[![CODESPACES](https://img.shields.io/badge/ABRIR_EN-CODESPACES-000000?style=for-the-badge&labelColor=ffffff&logo=github&logoColor=000000)](https://codespaces.new/jeancodeeer/Jean-API-Generator)

[`ENGLISH`](README.md) · **`ESPAÑOL`**

</div>

```
N° 001 — JEANCODE-API                                                REF. V0.7
Sirve los modelos GGUF Jean como una API gratuita compatible con OpenAI.
llama.cpp `llama-server` · GitHub Codespaces · solo CPU · contexto 128k
```

> [!TIP]
> **¿Prefieres un cliente gráfico?** Conecta **[JeanCode](https://github.com/jeancodeeer/JeanCode)** a tu propio `Jean-API-Generator`: chat, un generador de código con proyectos descargables y un agente de escritorio para Windows, macOS y Linux.

<br>

## 01 — QUÉ ES

`Jean-API-Generator` es la capa de despliegue de los modelos **Jean v0.7** (**Grey**, **Marvel** y **Fénix**, ajustados a partir de Qwen3.5-27B y publicados en GGUF en Hugging Face). Convierte un Codespace de GitHub en un servidor de inferencia de LLM autoalojado que habla la **API de OpenAI** (`/v1/chat/completions`, `/v1/models`): cualquier cliente, editor o agente de código compatible solo necesita cambiar la URL base y la clave.

Nada se ejecuta en tu equipo: tu PC solo es un cliente HTTP.

<br>

## 02 — QUÉ HACE

Comprobable en el código:

| | |
|---|---|
| **`llama-server` por modelo** | `serve.sh {grey\|marvel\|fenix}` descarga el GGUF y lanza `llama-server` con autenticación Bearer (`--api-key`). |
| **128k de contexto en CPU** | `-c 131072` con caché KV cuantizada (`-ctk q8_0 -ctv q8_0`). |
| **Dos modelos a la vez** | Grey (`:8888`) y Marvel (`:8889`) caben juntos en 16 GB (mediciones en [docs/HISTORY.md](docs/HISTORY.md)). |
| **Arranque y recuperación** | Arranque automático según la RAM disponible y *watchdog* que relanza servidores caídos cada 60 s. |
| **Modo persistente** | `.jean-mode` (`standard` \| `fenix`); los GGUF viven en `gguf/` y sobreviven a reinicios. |
| **Fuera de Codespaces** | `generator/` (bash/PowerShell) y `oracle/setup-vm.sh` (systemd). |
| **Control desde Windows** | `jean-api.ps1 start\|stop\|urls\|test\|status\|fenix-mode\|standard-mode` con `gh`. |

<br>

## 03 — MODELOS

Pesos públicos en **[JeanCoder/jean-models](https://huggingface.co/JeanCoder/jean-models)**.

| MODELO | ALIAS | ROL | TAMAÑO (Q4_K_M) |
|---|---|---|---|
| **JEAN GREY** | `jean-grey` · `:8888` | modelo de código principal | 2,52 GiB |
| **JEAN MARVEL** | `jean-marvel` · `:8889` | agente / segunda opinión | 4,36 GiB |
| **JEAN FÉNIX** | `jean-fenix` | modelo grande (Qwen3.5-27B + LoRA) | 15,41 GiB |

> [!WARNING]
> Fénix no es usable en un Codespace gratuito de 16 GB (~100 s/token medido con una variante reducida). Necesita una máquina ≥ 32 GB.

<br>

## 04 — INICIO RÁPIDO

```
[1] CREAR       →  Codespace desde este repo
[2] SECRET      →  JEAN_API_KEY
[3] INICIAR     →  autostart.sh lanza Grey (+ Marvel con ≥ 14 GB)
[4] PUBLICAR    →  reenviar puertos 8888 / 8889 como públicos
```

1. Crea un Codespace desde este repo ([ábrelo aquí](https://codespaces.new/jeancodeeer/Jean-API-Generator)).
2. Añade el secret `JEAN_API_KEY` (la clave que tú eliges). `HF_TOKEN` es opcional: los modelos son públicos.
3. Inicia el Codespace: `autostart.sh` lanza Grey y, con ≥ 14 GB de RAM, Marvel.
4. Reenvía los puertos 8888/8889 como públicos (los protege la clave).

```bash
curl -s "https://<tu-url-8888>/v1/chat/completions" \
  -H "Authorization: Bearer $JEAN_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"hola"}]}'
```

| RESPUESTA | SIGNIFICADO |
|---|---|
| `401` | falta la cabecera Bearer o la clave es incorrecta |
| `503` al despertar | el modelo aún está cargando |

### Una sola URL: el router (puerto 8899)

`https://<codespace>-8899.app.github.dev/v1` muestra todos los modelos del Codespace, incluidos los GGUF que cargues desde Hugging Face con [JeanCode](https://github.com/jeancodeeer/JeanCode).
- `"model": "auto"` elige el primero listo (grey > marvel > fenix).
- Si un modelo no está disponible, responde `503` con la lista de los que sí lo están. Nunca cambia de modelo a escondidas.
- `/v1/models` dice qué puerto está caído y por qué, por ejemplo «Fénix no cabe en esta RAM».
- En modo Fénix, el Codespace elige en Hugging Face el GGUF de Fénix que cabe en su memoria.
- `serve.sh` no arranca sin `JEAN_API_KEY`.

<br>

## 05 — ESTRUCTURA, LÍMITES Y MÁS

La estructura del proyecto, los límites conocidos (el Codespace se duerme, solo CPU, 3 modelos a 128k no caben) y el roadmap están en el [README en inglés](README.md). La cronología con pruebas y decisiones está en [docs/HISTORY.md](docs/HISTORY.md).

<br>

## 06 — SEGURIDAD · CONTRIBUIR · LICENCIA

Ver [SECURITY.md](SECURITY.md) y [CONTRIBUTING.md](CONTRIBUTING.md). Todavía no hay archivo de licencia publicado; los pesos derivan de [Qwen3.5-27B](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF), revisa su licencia antes de redistribuirlos.

<div align="center">

<br>

```
JEANCODER © 2026 — GREY ■ MARVEL ■ FÉNIX
```

</div>
