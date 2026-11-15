<div align="center">

<img src="assets/social-preview.svg" alt="Jean-API-Generator — tu propia API de LLM gratis y compatible con OpenAI en GitHub Codespaces, servida con llama.cpp" width="100%">

<br>

# Tu propia API de LLM gratis y compatible con OpenAI — en un Codespace de GitHub

**Sin GPU, sin tarjeta, sin factura de API.** Un Codespace ejecuta [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` con los modelos Jean (o cualquier GGUF de Hugging Face) y te da **una sola URL** que funciona en cualquier cliente compatible con OpenAI: [JeanCode](https://github.com/jeancodeeer/JeanCode), los SDK de OpenAI, `curl` y los agentes o editores que permiten poner una URL base propia.

<br>

[![MODELOS](https://img.shields.io/badge/MODELOS-JEANCODER%2FJEAN--MODELS-ffffff?style=for-the-badge&labelColor=000000)](https://huggingface.co/JeanCoder/jean-models)
[![MOTOR](https://img.shields.io/badge/MOTOR-LLAMA.CPP-ffffff?style=for-the-badge&labelColor=000000)](https://github.com/ggml-org/llama.cpp)
![API](https://img.shields.io/badge/API-COMPATIBLE_OPENAI-ffffff?style=for-the-badge&labelColor=000000)
[![KAGGLE](https://img.shields.io/badge/EJECUTAR_EN-KAGGLE_GPU-000000?style=for-the-badge&labelColor=ffffff&logo=kaggle&logoColor=000000)](kaggle/jean-api.ipynb)
[![CODESPACES](https://img.shields.io/badge/ABRIR_EN-CODESPACES-000000?style=for-the-badge&labelColor=ffffff&logo=github&logoColor=000000)](https://codespaces.new/jeancodeeer/Jean-API-Generator)

[`ENGLISH`](README.md) · **`ESPAÑOL`**

</div>

```
N° 001 — JEANCODE-API                                                REF. V0.7
Sirve los modelos GGUF Jean como una API gratuita compatible con OpenAI.
llama.cpp `llama-server` · Kaggle (GPU gratis) o GitHub Codespaces (CPU)
```

> [!TIP]
> **¿Prefieres un cliente gráfico?** Conecta **[JeanCode](https://github.com/jeancodeeer/JeanCode)** a tu propio `Jean-API-Generator`: chat, un generador de código con proyectos descargables y un agente de escritorio para Windows, macOS y Linux.

<br>

## 01 — QUÉ ES

`Jean-API-Generator` es la capa de despliegue de los modelos **Jean v0.7** (**Grey**, **Marvel** y **Fénix**, ajustados a partir de Qwen3.5-27B y publicados en GGUF en Hugging Face). Convierte un Codespace de GitHub en un servidor de inferencia de LLM autoalojado que habla la **API de OpenAI** (`/v1/chat/completions`, `/v1/models`): cualquier cliente, editor o agente de código compatible solo necesita cambiar la URL base y la clave.

Nada se ejecuta en tu equipo: tu PC solo es un cliente HTTP.

**Por qué usarlo**

- **Gratis y tuyo.** Tu clave, tu Codespace, tus registros. Nadie se pone entre tú y el modelo.
- **Una URL para todo.** El router en `:8899` expone todos los modelos del Codespace, con el contexto real de cada uno.
- **Cualquier GGUF, no solo Jean.** Carga un modelo del Hub de Hugging Face en un puerto sin abrir el Codespace (servidor de control).
- **Honesto con sus límites.** Dice *por qué* un modelo no está disponible (cargando, apagado, no cabe en la RAM) en vez de fallar en silencio. Solo CPU: velocidad de modelo pequeño, no de GPU.

> [!IMPORTANT]
> **Uso personal, tu propio Codespace.** Este repositorio es una receta que ejecutas en **tu** cuenta de GitHub, para **ti**. No es un servicio alojado ni debe ofrecerse como tal: los términos de GitHub para Codespaces restringen ofrecerlos como servicio independiente o comercial y pueden suspender las cuentas que los usen mal. No compartas tu URL ni tu clave. Medido en la máquina gratuita de 4 núcleos y 16 GB: unos **8 tokens/s** con Jean Grey, contexto de **131k** (Marvel: 32k), y el Codespace **se duerme tras 30 minutos sin uso**. Para trabajo rápido o pesado, conecta tu cliente a otra API.

**Mejor en pareja.** Combínalo con **[JeanCode](https://github.com/jeancodeeer/JeanCode)**, un agente de programación y cliente de chat sin backend propio (escritorio, web, Android, iOS): pega la URL de este router y tienes un asistente privado sin nadie en el medio.

```bash
# la versión de 30 segundos, con tu Codespace ya encendido
curl -s https://<codespace>-8899.app.github.dev/v1/models -H "Authorization: Bearer $JEAN_API_KEY"
```

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

### Opción A — Kaggle (GPU gratis, sin tarjeta): la recomendada

Kaggle da a cada cuenta con el teléfono verificado **dos GPU NVIDIA T4** gratis, unas 30 horas a la semana, que se renuevan **cada semana**. Con ellas los modelos Jean corren en GPU, mucho más rápido que en cualquier máquina gratuita de CPU, y cabe hasta Fénix.

```
[1] VERIFICA    →  tu teléfono en Kaggle (necesario para GPU e internet)
[2] IMPORTA     →  kaggle/jean-api.ipynb en un notebook nuevo de Kaggle
[3] AJUSTES     →  Accelerator: GPU T4 x2 · Internet: On
[4] SECRETO     →  opcional: Add-ons → Secrets → JEAN_API_KEY
[5] RUN ALL     →  copia la URL que imprime en JeanCode
```

1. En Kaggle: **Create → New Notebook → File → Import Notebook** y elige [`kaggle/jean-api.ipynb`](kaggle/jean-api.ipynb) de este repositorio.
2. En el panel derecho, **Settings**: *Accelerator* `GPU T4 x2`, *Internet* `On`.
3. *(Opcional)* **Add-ons → Secrets → Add secret**, nombre `JEAN_API_KEY`, valor: una clave larga y aleatoria, para tener siempre la misma; nunca aparece en el código ni en la salida. Sin ella, el notebook crea una clave para cada sesión y la muestra junto a la URL (la salida de tu notebook solo la ves tú).
4. **Run All.** En 3–6 minutos aparece un recuadro con la URL (`https://….trycloudflare.com/v1`) y la clave. Pega las dos en JeanCode.

Qué hace el notebook: clona este repositorio y ejecuta [`kaggle/launch.py`](kaggle/launch.py), que instala el binario oficial de llama.cpp con CUDA (no compila nada), sirve cada modelo con el mismo `serve.sh` en su propia GPU, arranca el mismo router en `:8899` y abre un túnel de Cloudflare hacia él. Si un modelo o el túnel se caen, los relanza.

**Modelos:** edita `MODELOS` en el notebook: `grey`, `marvel`, `fenix` (las dos GPU), `hf:usuario/repo/archivo.gguf` para cualquier GGUF de Hugging Face (añade el secreto `HF_TOKEN` para los privados) o `file:/kaggle/input/…/modelo.gguf` para un GGUF tuyo subido como dataset y añadido con **Add Input**. El panel de Hugging Face de JeanCode carga más modelos mientras corre.

**Límites:** una sesión de Kaggle dura hasta ~12 horas; después pulsa **Run All** otra vez y la URL cambia. Los términos de Kaggle permiten uso personal y no comercial: es tu propia API para ti, no un servicio para otros.

### Opción B — GitHub Codespaces (CPU)

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

## 04b — BENCHMARK REPRODUCIBLE

Nada de afirmaciones de calidad sin números que puedas repetir. `tests/bench_humaneval.py` ejecuta [HumanEval](https://github.com/openai/human-eval), el banco público de OpenAI, contra **cualquier** API compatible con OpenAI, a temperatura 0 y sin razonamiento, y guarda cada resultado en `bench/humaneval-<modelo>.json`:

```bash
# dentro de tu Codespace (ejecuta el código que escribe el modelo: mejor ahí que en tu PC)
python3 tests/bench_humaneval.py --model jean-grey --n 40     # los 40 primeros problemas
python3 tests/bench_humaneval.py --model jean-marvel          # los 164
```

Los resultados se publican en [`bench/`](bench/) a medida que se miden, con el subconjunto, la fecha y el tiempo. El mismo script sirve contra Groq, OpenRouter u Ollama local, para comparar en igualdad de condiciones.

## 05 — ESTRUCTURA, LÍMITES Y MÁS

La estructura del proyecto, los límites conocidos (el Codespace se duerme, solo CPU, 3 modelos a 128k no caben) y el roadmap están en el [README en inglés](README.md). La cronología con pruebas y decisiones está en [docs/HISTORY.md](docs/HISTORY.md).

<br>

## 06 — SEGURIDAD · CONTRIBUIR · LICENCIA

Ver [SECURITY.md](SECURITY.md) y [CONTRIBUTING.md](CONTRIBUTING.md). El código de este repositorio se publica bajo licencia [MIT](LICENSE). Los pesos derivan de [Qwen3.5-27B](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF), revisa su licencia antes de redistribuirlos.

<div align="center">

<br>

```
JEANCODER © 2026 — GREY ■ MARVEL ■ FÉNIX
```

</div>
