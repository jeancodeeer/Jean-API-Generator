# Jean v0.7 — modelos de código libres y su API

Tres modelos de código entrenados por Jean sobre la familia **Qwen3.5**,
publicados **para todo el mundo** en HuggingFace y con una API compatible
con OpenAI que puedes levantar **donde quieras**.

Este repositorio **no ejecuta nada por sí mismo**: es el manual + el
generador + los scripts de despliegue.

---

## 1. ¿Qué es exactamente?

| modelo | base | tamaño | qué es |
|---|---|---|---|
| **Jean Grey** | Qwen3.5-4B | 2.52 GiB | el primario de código (eval n=60: 0.4833) |
| **Jean Marvel** | Qwen3.5-7B | 4.06 GiB | agente secundario |
| **Jean Fénix** | Qwen3.5-27B | 15.41 GiB (Q4_K_M) o ~18.6 GiB (Q5_K_M, casi sin degradación) | el grande, entrenado con LoRA (rank 64, alpha 128) |

Todos son ficheros **GGUF** estándar de llama.cpp: un solo archivo cada uno,
descargables **sin token** de [JeanCoder/jean-models](https://huggingface.co/JeanCoder/jean-models).

**Un fichero GGUF NO se ejecuta solo.** Necesita un motor: **llama.cpp**
(`llama-server`), que lo sirve como una API con el mismo formato que OpenAI
(`/v1/chat/completions`). Ese motor puede correr en tu PC o en la nube.

## 2. ¿Dónde se ejecuta? (la parte que confunde)

```
  tu app / CLI (OpenCode, curl, ...)          <== SOLO envía HTTP, no procesa nada
        │  Authorization: Bearer <clave>
        ▼
  ¿dónde corre el modelo? (elige UNA)
  ┌─────────────────────────────────────────────────────────────┐
  │ A) Tu PC         (si tiene RAM: grey 4GB, marvel 6GB)       │
  │ B) GitHub Codespace (free, 4c/16GB: grey + marvel a la vez) │
  │ C) Oracle Always Free ARM (24GB: fenix Q5_K_M permanente)   │
  └─────────────────────────────────────────────────────────────┘
```

**Tu PC nunca necesita potencia salvo que elijas la opción A.** Con B o C,
el procesamiento ocurre íntegramente en el servidor; tu máquina solo espera
la respuesta (igual que al usar cualquier API de internet).

## 3. Los ficheros y su integridad (sha256)

```
jean-grey-v0.7.Q4_K_M.gguf    2.52 GiB
jean-marvel-v0.7.Q4_K_M.gguf  4.06 GiB
jean-fenix-v0.7.Q4_K_M.gguf   15.41 GiB
jean-fenix-v0.7.Q5_K_M.gguf   ~18.6 GiB   (Oracle: "casi nada degradada")
jean-fenix-v0.7.lora.gguf     0.59 GiB    (adapter alternativo, ligero)
```

Los sha256 exactos están en el RUNLOG del proyecto y en los `*.manifest.json`
del release `v0.7-models` de este repo (espejo de HF, en trozos < 2 GiB).

## 4. Forma A — en tu PC (generador por terminal)

**Windows** (PowerShell 5.1+, viene de serie):

```powershell
.\generator\jean-api-generator.ps1 -Model grey        # clave auto-generada
.\generator\jean-api-generator.ps1 -Status
.\generator\jean-api-generator.ps1 -Stop -Port 8888
```

**macOS / Linux / WSL** (bash):

```bash
chmod +x generator/jean-api-generator.sh
./generator/jean-api-generator.sh start grey          # clave auto-generada
./generator/jean-api-generator.sh status
./generator/jean-api-generator.sh stop --port 8888
```

Qué hace el generador (ambos son equivalentes):

1. descarga el GGUF de HF **público** (con resume, cache local)
2. consigue `llama-server` (prebuilt del release oficial; compila si no hay)
3. arranca la API **solo en 127.0.0.1** con prioridad baja
4. genera una **clave aleatoria propia de esa instancia** (`key-<puerto>.txt`)
5. nada de esto toca ningún repo: modelos, logs y claves van al `.gitignore`

## 5. Forma B — nube gratuita de GitHub (Grey + Marvel)

Un Codespace de 4 cores / 16 GB corre **Grey y Marvel a la vez**. Tu PC solo
habla con la URL estable del Codespace.

```powershell
# en tu PC (necesita $env:GH_TOKEN = tu PAT):
.\jean-api.ps1 start    # arranca el codespace, publica puertos, espera modelos
.\jean-api.ps1 test     # prueba inferencia + comprueba 401 sin clave
.\jean-api.ps1 stop     # apaga (deja de gastar cuota)
```

- Cuota free: 120 core-h/mes → ~30 h de uso a 4 cores; idle timeout 60 min.
- Las URLs son `https://<nombre-codespace>-{8888|8889}.app.github.dev/v1`
  y la clave vive SOLO en tu PC (variable `JEAN_API_KEY`).

## 6. Forma C — Oracle Always Free ARM (Fénix permanente) ★

Una VM **Ampere A1 de 4 OCPU / 24 GB RAM** es **Always Free** en Oracle
Cloud y aguanta Fénix Q5_K_M con margen (la "casi nada degradada": Q5_K_M
retiene ~98-99% de la calidad del F16 original; Q4_K_M retiene algo menos y
también vale).

**Paso 1 — cuenta.** En [cloud.oracle.com](https://cloud.oracle.com) crea la
cuenta Free Tier. **Ojo:** Oracle pide tarjeta solo para **verificar**
identidad (preautorización que no se cobra); el tier Always Free no factura
nada. Si no quieres darla, usa la forma A/B y salta este apartado.

**Paso 2 — instancia.** Consola → Create Instance:
- Shape: **Ampere A1** (VM.Standard.A1.Flex), **4 OCPU / 24 GB**
- Imagen: **Ubuntu 22.04 o 24.04** (aarch64)
- Boot volume: 50 GB (hay 200 GB free en total)
- Descarga TU clave SSH o pega una pública

**Paso 3 — abrir el puerto.** Consola → Networking → Security List →
Add Ingress Rule: origen `0.0.0.0/0`, TCP, puerto destino `8890`.

**Paso 4 — desplegar (un comando dentro de la VM):**

```bash
ssh ubuntu@<IP_PUBLICA>
curl -fsSL https://raw.githubusercontent.com/jeancodeeer/jean-api/main/oracle/setup-vm.sh -o setup.sh
sudo bash setup.sh --model fenix --api-key "mi-clave-secreta"
```

El script instala llama.cpp, descarga Fénix de HF público, crea un servicio
**systemd** (se levanta solo al reiniciar la VM), abre el firewall local y
te imprime la URL:

```
URL pública : http://<IP_PUBLICA>:8890/v1
API key     : mi-clave-secreta
```

Coste: **0 €/mes** (Always Free: 4 OCPU + 24 GB + 200 GB siempre gratis).
Tu PC sigue siendo solo un cliente.

## 7. Conectar con tu CLI favorito

Cualquier cliente que hable OpenAI-compatible sirve apuntándolo a la URL
elegida (local, Codespace o Oracle) con su clave.

**OpenCode** (`~/.config/opencode/opencode.jsonc`):

```jsonc
"providers": {
  "jean": {
    "package": "@opencode/ai/providers/openai-compatible",
    "settings": {
      "baseURL": "http://<IP_ORACLE>:8890/v1",   // o la URL del Codespace
      "apiKey": "{env:JEAN_API_KEY}"             // clave en variable de entorno
    },
    "models": {
      "fenix": { "modelID": "jean-fenix", "limit": { "context": 4096, "output": 3072 } }
    }
  }
}
```

Luego: `opencode --model jean/fenix`.

**Claude Code** (habla Anthropic): usa un puente local que traduzca
Anthropic→OpenAI, p. ej. con LiteLLM en otra terminal:

```bash
pip install "litellm[proxy]"
litellm --model openai/jean-fenix --api_base http://<IP_ORACLE>:8890/v1 \
        --api-key "<tu-clave>" --port 4000
ANTHROPIC_BASE_URL=http://127.0.0.1:4000 claude
```

**curl / Python** (directo, sin nada que instalar):

```bash
curl http://<TU_URL>/v1/chat/completions \
  -H "Authorization: Bearer <clave>" -H "Content-Type: application/json" \
  -d '{"model":"jean-fenix","messages":[{"role":"user","content":"hola"}]}'
```

```python
from openai import OpenAI
cli = OpenAI(base_url="http://<TU_URL>/v1", api_key="<clave>")
print(cli.chat.completions.create(model="jean-fenix",
      messages=[{"role":"user","content":"hola"}]).choices[0].message.content)
```

## 8. Estructura del repo

```
README.md                        este manual
generator/jean-api-generator.ps1 generador Windows
generator/jean-api-generator.sh  generador macOS/Linux/WSL
generator/check_lora.py          valida adapter↔base leyendo solo cabeceras
generator/gguf_info.py           info de cabeceras GGUF
oracle/setup-vm.sh               despliegue permanente en Oracle A1 (systemd)
serve.sh                         sirve un modelo (usado por Codespace)
.devcontainer/                   Codespace: autostart + watchdog
jean-api.ps1                     control del Codespace (start/stop/test)
logs/                            vaciado (nada de URLs ni claves aquí)
```

## 9. FAQ

- **¿Corre algo en mi PC?** Solo si eliges la forma A. Con B o C tu PC es un
  cliente HTTP puro: la inferencia ocurre en el servidor.
- **¿Cuánto cuesta?** HF y el generador: gratis. Codespace: gratis dentro de
  120 core-h/mes. Oracle A1: 0 € siempre (4 OCPU/24 GB). Sin tarjeta que
  cobre: la de Oracle solo verifica identidad.
- **¿Es seguro exponer la IP?** La API exige `Authorization: Bearer` siempre
  (verificado: sin clave → 401). Añade una clave larga o restringe el puerto
  a tu IP si lo prefieres.
- **¿Fénix Q4 o Q5?** Q5_K_M pierde *casi nada* respecto al original y cabe
  cómodo en los 24 GB de Oracle; Q4_K_M es más pequeño (para PCs de 32 GB).
- **¿Puedo usar Grey/Marvel también en Oracle?** Sí: `--model grey` en el
  setup-vm (o corre varios en puertos distintos si la RAM lo permite).
