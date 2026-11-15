<div align="center">

<img src="assets/social-preview.svg" alt="Jean-API-Generator — tu propia API de LLM gratis y compatible con OpenAI en las GPU gratis de Kaggle o en tu propia máquina, servida con llama.cpp" width="100%">

<br>

# Tu propia API de LLM gratis y compatible con OpenAI

**Sin tarjeta, sin factura de API y sin ningún servidor mío en medio.** Un comando (o un notebook de Kaggle) ejecuta [llama.cpp](https://github.com/ggml-org/llama.cpp) `llama-server` con los modelos Jean (o cualquier GGUF de Hugging Face) y te da **una sola URL** que funciona en cualquier cliente compatible con OpenAI: [JeanCode](https://github.com/jeancodeeer/JeanCode), los SDK de OpenAI, `curl` y los agentes o editores que permiten poner una URL base propia.

<br>

[![MODELOS](https://img.shields.io/badge/MODELOS-JEANCODER%2FJEAN--MODELS-ffffff?style=for-the-badge&labelColor=000000)](https://huggingface.co/JeanCoder/jean-models)
[![MOTOR](https://img.shields.io/badge/MOTOR-LLAMA.CPP-ffffff?style=for-the-badge&labelColor=000000)](https://github.com/ggml-org/llama.cpp)
![API](https://img.shields.io/badge/API-COMPATIBLE_OPENAI-ffffff?style=for-the-badge&labelColor=000000)
[![KAGGLE](https://img.shields.io/badge/EJECUTAR_EN-KAGGLE_GPU-000000?style=for-the-badge&labelColor=ffffff&logo=kaggle&logoColor=000000)](kaggle/jean-api.ipynb)

[`ENGLISH`](README.md) · **`ESPAÑOL`**

</div>

```
N° 001 — JEANCODE-API                                                REF. V0.7
Sirve los modelos GGUF de Jean como una API gratis y compatible con OpenAI.
llama.cpp `llama-server` · Kaggle (GPU gratis) · tu PC · cualquier VM Linux
```

> [!TIP]
> **¿Prefieres una interfaz gráfica?** Conecta **[JeanCode](https://github.com/jeancodeeer/JeanCode)** a tu propio `Jean-API-Generator`: chat, un generador de código con proyectos descargables y un agente de escritorio para Windows, macOS y Linux.

<br>

## 01 — QUÉ ES

`Jean-API-Generator` es la capa de despliegue de los modelos **Jean v0.7** (**Grey**, **Marvel** y **Fénix**, ajustados a partir de Qwen3.5-27B y publicados como GGUF en Hugging Face). Convierte una máquina que controlas en un servidor de inferencia propio que habla la **API de OpenAI** (`/v1/chat/completions`, `/v1/models`): cualquier cliente, editor o agente compatible con OpenAI usa los modelos cambiando solo la URL base y la clave.

**Dónde corre:** en las GPU gratis de **Kaggle** (la recomendada: sin tarjeta y se renueva cada semana), en **tu propio PC** (Linux, WSL, Windows o macOS) o en **cualquier VM Linux**. Cada persona lo ejecuta con su propia cuenta y su propia clave: no hay un servidor compartido.

**Por qué usarlo**

- **Gratis y tuyo.** Tu clave, tu máquina, tus registros. Nadie se pone entre tú y el modelo.
- **Una URL para todo.** El router en `:8899` expone todos los modelos que sirves, con el contexto real de cada uno.
- **Cualquier GGUF, no solo Jean.** Sirve cualquier GGUF de Hugging Face, o carga uno mientras corre (servidor de control, más abajo).
- **Honesto con sus límites.** Te dice *por qué* un modelo no está disponible (cargando, apagado, no cabe en la memoria) en vez de fallar en silencio.

> [!IMPORTANT]
> **Uso personal.** Este repositorio es una receta que ejecutas en **tu** cuenta o en **tu** máquina, para **ti**. No es un servicio alojado. Las condiciones de Kaggle permiten uso personal y no comercial: no ofrezcas tu URL de Kaggle a otros. No compartas tu URL ni tu clave.

**Forma pareja con** **[JeanCode](https://github.com/jeancodeeer/JeanCode)**, un agente de programación y cliente de chat sin backend propio (escritorio, web, Android, iOS, pygame): pega la URL de este router y tienes un asistente privado sin nadie en medio.

```bash
# la versión de 30 segundos, cuando ya imprimió su URL
curl -s https://<tu-url>/v1/models -H "Authorization: Bearer $JEAN_API_KEY"
```

<br>

## 02 — QUÉ HACE

Lo que hace de verdad el código de este repositorio:

| | |
|---|---|
| **Un solo lanzador** | `launch.py` instala llama.cpp oficial (CUDA si hay GPU NVIDIA, CPU si no; no compila nada), sirve cada modelo en su puerto y su GPU, arranca el router y abre una URL pública. El notebook de Kaggle llama al mismo archivo. |
| **`llama-server` por modelo** | `serve.sh {grey\|marvel\|fenix\|custom}` descarga el GGUF y arranca `llama-server` con clave Bearer (`--api-key`). Es la única fuente de los parámetros del servidor. |
| **Contexto largo** | Caché KV cuantizada (`-ctk q8_0 -ctv q8_0`); el contexto por modelo se elige con `JEAN_CTX` (32k por defecto con el lanzador, hasta 128k). El contexto nativo de los GGUF es 262144. |
| **Varios modelos, varias GPU** | Grey y Marvel van a una GPU cada uno; Fénix (o un solo modelo) usa todas. Se saltan los puertos ocupados. |
| **Recuperación** | El lanzador revisa cada minuto y relanza el modelo, el router o el túnel que se haya caído, mostrando el final de su registro. |
| **URL pública** | Un túnel rápido de Cloudflare hacia el router (`https://….trycloudflare.com/v1`). Con `JEAN_TUNNEL=0` queda solo en `http://127.0.0.1:8899/v1`. |
| **Windows / macOS nativos** | `generator/` (PowerShell y bash) arranca un modelo en tu PC con el contexto según la RAM, escuchando solo en `127.0.0.1`. |
| **VM permanente** | `oracle/setup-vm.sh` instala un modelo como servicio **systemd** en una VM Ubuntu/Debian (x86_64 o ARM). |
| **Herramientas** | `tools/` trae un lector de cabeceras GGUF, una comprobación de integridad del LoRA y un divisor de GGUF. |

<br>

## 03 — MODELOS

Los pesos son públicos en Hugging Face: **[JeanCoder/jean-models](https://huggingface.co/JeanCoder/jean-models)** (se descargan sin token).

| MODELO | SE SIRVE COMO | PAPEL | GGUF | TAMAÑO |
|---|---|---|---|---|
| **JEAN GREY** | `jean-grey` | modelo principal de código | `jean-grey-v0.7.Q4_K_M.gguf` | 2.52 GiB |
| **JEAN MARVEL** | `jean-marvel` | agente / segunda opinión | `jean-marvel-v0.7.Q4_K_M.gguf` | 4.36 GiB |
| **JEAN FÉNIX** | `jean-fenix` | modelo grande (Qwen3.5-27B + LoRA) | `jean-fenix-v0.7.Q4_K_M.gguf` (+ Q5_K_M, adaptador LoRA) | 15.41 GiB |

> [!WARNING]
> **Fénix necesita unos 16 GB de memoria de GPU o ≥ 32 GB de RAM.** En Kaggle cabe entre las dos GPU T4. En una máquina de 16 GB sin GPU una variante reducida cargó, pero generaba a unos 100 s por token (medido, ver [docs/HISTORY.md](docs/HISTORY.md)).

<br>

## 04 — INICIO RÁPIDO

### Opción A — Kaggle (GPU gratis, sin tarjeta): la recomendada

Kaggle da a toda cuenta con el teléfono verificado **dos GPU NVIDIA T4** gratis, unas 30 horas a la semana, renovadas **cada semana**. Con ellas los modelos Jean corren en GPU, mucho más rápido que en cualquier máquina gratis sin GPU, y hasta Fénix cabe.

```
[1] VERIFICA    →  tu teléfono en Kaggle (hace falta para GPU e internet)
[2] IMPORTA     →  kaggle/jean-api.ipynb en un notebook nuevo de Kaggle
[3] AJUSTES     →  Accelerator: GPU T4 x2 · Internet: On
[4] SECRETO     →  opcional: Add-ons → Secrets → JEAN_API_KEY
[5] RUN ALL     →  copia en JeanCode la URL que imprime
```

1. En Kaggle: **Create → New Notebook → File → Import Notebook** y elige [`kaggle/jean-api.ipynb`](kaggle/jean-api.ipynb) de este repositorio.
2. En el panel derecho, **Settings**: *Accelerator* `GPU T4 x2`, *Internet* `On`.
3. *(Opcional)* **Add-ons → Secrets → Add secret**, nombre `JEAN_API_KEY`, valor: una clave larga, para tener siempre la misma; nunca aparece en el código ni en la salida. Sin ella, el notebook crea una clave en cada sesión y la muestra junto a la URL (la salida de tu notebook solo la ves tú).
4. **Run All.** En 3–6 minutos un recuadro muestra la URL (`https://….trycloudflare.com/v1`) y la clave. Pega las dos en JeanCode.

**Modelos:** cambia `MODELOS` en el notebook: `grey`, `marvel`, `fenix` (las dos GPU), `hf:usuario/repo/archivo.gguf` para cualquier GGUF de Hugging Face (añade el secreto `HF_TOKEN` si es privado) o `file:/kaggle/input/…/modelo.gguf` para un GGUF tuyo subido como dataset y añadido con **Add Input**.

**Límites:** una sesión de Kaggle dura hasta ~12 horas; después pulsa **Run All** otra vez y la URL cambia.

### Opción B — tu propio PC o cualquier máquina Linux

En Linux x86_64 o **WSL** (Windows), con o sin GPU NVIDIA; también en Colab o un VPS:

```bash
git clone https://github.com/jeancodeeer/Jean-API-Generator && cd Jean-API-Generator
python3 launch.py                                   # Grey + Marvel, URL pública, la clave se muestra una vez
```

```bash
export JEAN_API_KEY=elige-una-clave-larga           # una clave fija (si no, una por ejecución)
JEAN_MODELS=grey JEAN_TUNNEL=0 python3 launch.py    # solo Grey, solo en http://127.0.0.1:8899/v1
JEAN_MODELS=hf:unsloth/Qwen3-4B-GGUF/Qwen3-4B-Q4_K_M.gguf python3 launch.py   # cualquier GGUF
```

Necesita Python 3.8+, `bash` e internet la primera vez. Sin GPU corre en la CPU: funciona, a velocidad de modelo pequeño (medido en 4 núcleos: una respuesta de una palabra en 8,4 s con Grey). Lo que descarga queda en `~/.cache/jean-api` y `gguf/`. `Ctrl+C` lo detiene todo.

**Windows o macOS nativos (sin WSL):** los scripts de [`generator/`](generator/README.md) arrancan un modelo en `127.0.0.1`:

```powershell
.\generator\jean-api-generator.ps1 -Model grey       # Windows
```
```bash
./generator/jean-api-generator.sh start grey         # macOS / Linux
```

### Opción C — una VM permanente

```bash
sudo bash oracle/setup-vm.sh --model grey --api-key "…"   # servicio systemd en Ubuntu/Debian
```

Pensado para la VM ARM Always Free de Oracle Cloud (24 GB, suficiente para Fénix); funciona en cualquier VM Ubuntu/Debian.

<br>

## 05 — USO

Funciona con cualquier cliente compatible con OpenAI. Con `curl`:

```bash
BASE="https://<tu-url>/v1"            # o http://127.0.0.1:8899/v1 en la misma máquina

curl -s "$BASE/chat/completions" \
  -H "Authorization: Bearer $JEAN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"Escribe una función de Python que invierta una cadena."}]}'
```

Con el SDK de OpenAI para Python:

```python
from openai import OpenAI

client = OpenAI(base_url="https://<tu-url>/v1", api_key="<JEAN_API_KEY>")
r = client.chat.completions.create(
    model="jean-grey",
    messages=[{"role": "user", "content": "Explica qué es un mutex en dos frases."}],
)
print(r.choices[0].message.content)
```

| RESPUESTA | SIGNIFICA |
|---|---|
| `401` | falta la cabecera Bearer o la clave es incorrecta |
| `503` justo al arrancar | el modelo aún se descarga o carga (2–5 minutos la primera vez) |

<br>

## 05a — UNA URL PARA TODOS LOS MODELOS (ROUTER)

El puerto **:8899** es un router compatible con OpenAI: la URL que imprime el lanzador apunta a él, y ve todos los modelos que sirves, incluidos los GGUF que cargues de Hugging Face.

| MÉTODO | RUTA | QUÉ HACE |
|---|---|---|
| `GET` | `/v1/models` | modelos listos en todos los puertos, más `jean.unavailable`: qué puerto está caído y por qué (cargando, apagado, "Fénix no cabe en esta RAM") |
| `POST` | `/v1/chat/completions` · `/v1/completions` · `/v1/embeddings` | se envía al puerto que sirve `model`, con el streaming intacto |
| `GET` | `/health` | público y sin datos: `{"ok": true, "ready": 2}` |
| `GET` `POST` | `/relay/<host>/<ruta>` | **relay CORS** para clientes web y móviles: reenvía a APIs que bloquean el navegador (NVIDIA NIM, SambaNova, Z.ai…). Solo a una lista fija de proveedores conocidos (más los tuyos con `JEAN_RELAY_HOSTS`), solo https, sin redirecciones. Pide `X-Jean-Key: $JEAN_API_KEY`; la clave del proveedor en `Authorization` pasa sin tocarse y nunca se registra. |

- `"model": "auto"` elige el primer modelo listo (grey > marvel > fenix > otros); también vale un nombre parcial único (`"fenix"`).
- Nunca cambia de modelo en silencio: un modelo no disponible recibe un `503` con la lista de los que están listos, en formato de error de OpenAI, y el cliente decide.
- La misma `JEAN_API_KEY` que en todos los puertos. La respuesta dice qué modelo contestó (`X-Jean-Model`).
- Pruebas: `python tests/test_router.py` (corre en CI con llama-servers falsos).

<br>

## 05b — CARGAR CUALQUIER MODELO DE HUGGING FACE MIENTRAS CORRE (SERVIDOR DE CONTROL)

`control/control_server.py` es el mismo proceso del **:8899**, protegido con tu `JEAN_API_KEY`. Un cliente como **[JeanCode](https://github.com/jeancodeeer/JeanCode)** lo usa para poner cualquier GGUF de Hugging Face en uno de los puertos de modelo sin tocar la máquina:

| MÉTODO | RUTA | QUÉ HACE |
|---|---|---|
| `GET` | `/status` | modelo por puerto, RAM y disco libres, descargas en curso |
| `POST` | `/load` `{repo, file, slot, hf_token?, ctx?}` | comprueba disco y RAM, descarga el GGUF a `gguf/custom/` y lo sirve con `serve.sh custom` |
| `GET` | `/jobs/<id>` | progreso de la descarga |
| `POST` | `/restore` `{slot}` | vuelve al modelo Jean de ese puerto |

`slot` es uno de los puertos de modelo. El token de HF, si se envía, solo se usa para esa descarga y nunca se guarda en disco. Un modelo cargado así aparece en el router al momento y va a la GPU si hay una. Al reiniciar vuelven los modelos de `JEAN_MODELS`. `serve.sh` no arranca sin `JEAN_API_KEY`, así que nunca se sirve un puerto sin clave.

<br>

## 06 — ESTRUCTURA

```
Jean-API-Generator/
├── launch.py                # el lanzador: llama.cpp + modelos + router + túnel + recuperación (cualquier Linux)
├── serve.sh                 # descarga el GGUF y lanza llama-server (única fuente de parámetros)
├── kaggle/                  # notebook de Kaggle (llama a launch.py)
├── control/                 # router y servidor de control en :8899
├── generator/               # lanzadores nativos para Windows (ps1) y macOS/Linux (sh), según la RAM
├── oracle/setup-vm.sh       # instalación systemd en una VM
├── tools/                   # utilidades GGUF/LoRA, mapa del proyecto
├── tests/                   # pruebas del router y del lanzador, contexto 128k, benchmark
├── docs/HISTORY.md          # mediciones, intentos fallidos y decisiones de diseño
└── graphify-out/            # grafo del código (generado con graphify)
```

<br>

## 06b — BENCHMARK REPRODUCIBLE

Nada de afirmaciones de calidad sin números que puedas repetir. `tests/bench_humaneval.py` ejecuta [HumanEval](https://github.com/openai/human-eval), público de OpenAI, contra **cualquier** endpoint compatible con OpenAI, a temperatura 0 y sin razonamiento, y guarda cada resultado en `bench/humaneval-<modelo>.json`:

```bash
# ejecuta el código que escribe el modelo: córrelo en Kaggle, una VM o un contenedor, no en tu PC
python3 tests/bench_humaneval.py --base-url http://localhost:8899/v1 --model jean-grey --n 40
python3 tests/bench_humaneval.py --base-url http://localhost:8899/v1 --model jean-marvel   # los 164
```

El mismo script funciona contra Groq, OpenRouter o un Ollama local, para comparar en igualdad de condiciones.

## 07 — LÍMITES

- Kaggle: sesiones de hasta ~12 horas y unas 30 horas de GPU a la semana; la URL cambia en cada ejecución.
- La URL del túnel es pública: la protege la clave. Sin GPU, espera velocidad de modelo pequeño.
- `launch.py` necesita Linux x86_64 (WSL cuenta); en Windows o macOS nativos usa `generator/`.

<br>

## 08 — SEGURIDAD · CONTRIBUIR · LICENCIA

- **Seguridad:** los secretos van solo por variables de entorno o Secrets de Kaggle; nunca subas claves ni URLs. Ver [SECURITY.md](SECURITY.md).
- **Contribuir:** issues y pull requests son bienvenidos; ver [CONTRIBUTING.md](CONTRIBUTING.md). Los parámetros del servidor viven solo en `serve.sh`; no los dupliques.
- **Licencia:** [MIT](LICENSE) para el código de este repositorio. Los pesos de Jean derivan de [Qwen3.5-27B](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF); revisa la licencia de origen antes de redistribuirlos.

<br>

## 09 — CRÉDITOS

[llama.cpp](https://github.com/ggml-org/llama.cpp) (`llama-server`) de ggml-org · base GGUF Qwen3.5-27B de Qwen / [Unsloth](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF) · [túneles rápidos de Cloudflare](https://github.com/cloudflare/cloudflared) · [graphify](https://github.com/Graphify-Labs/graphify) para el grafo de `graphify-out/`.

<div align="center">

<br>

```
JEANCODER © 2026 — GREY ■ MARVEL ■ FÉNIX
```

</div>
