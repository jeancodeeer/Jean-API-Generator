# Jean API — modelos Jean v0.7 como API OpenAI-compatible gratis en la nube

> Última actualización: **2026-11-06**. Este archivo es el mapa completo del proyecto:
> qué son los modelos, qué ha ocurrido, qué hace cada archivo y cómo operar todo.

**Una línea de resumen:** entrenamos 3 modelos (**Grey**, **Marvel**, **Fénix**, familia
v0.7, base Qwen3.5-27B), los publicamos en Hugging Face en abierto, y los servimos como
APIs OpenAI-compatible **gratis** desde un Codespace de GitHub — tu PC (8 GB RAM) solo
hace de cliente HTTP y jamás ejecuta un modelo.

---

## 1. Los 3 modelos (Jean v0.7)

| modelo | tag Ollama | rol | eval (n=60) | GGUF público | tamaño |
|---|---|---|---|---|---|
| **Jean Grey** | `jean-grey:v0.7-basic` | modelo de código (primario) | **0.4833** | `jean-grey-v0.7.Q4_K_M.gguf` | 2.52 GiB |
| **Jean Marvel** | `jean-marvel:v0.7-sagent` | agente/segunda opinión | 0.3667 | `jean-marvel-v0.7.Q4_K_M.gguf` | 4.36 GiB |
| **Jean Fénix** | `jean-fenix:v0.7-opus` | el "opus" grande | n.a. | `jean-fenix-v0.7.Q4_K_M.gguf` (full) | 15.41 GiB |

Variantes públicas también disponibles (repo HF):

| variante de Fénix | tamaño | dónde funciona |
|---|---|---|
| `Q5_K_M` (casi sin degradación) | 17.91 GiB | máquina ≥ 32 GB |
| `lite-IQ4_XS` | 14.15 GiB | máquina ≥ ~20 GB (en 16 GB no carga estable) |
| `lite-IQ3_M` | 11.72 GiB | 16 GB carga pero **~100 s/token → inútil** |
| `lora` (adaptador) | 0.59 GiB | entrenamiento/fusión |

**Detalles técnicos compartidos:** contexto nativo del GGUF **262144 (256k)**; al servir
se fija **131072 (128k)** con **KV cache q8_0** (`-ctk q8_0 -ctv q8_0`, ≈ 2 GiB de KV por
modelo a 128k). 128k con 2 modelos a la vez es el techo de la RAM de 16 GB (verificado en
vivo: 12,27/15,99 GB usados, 3,7 GB de margen). 3 modelos a 128k simultáneos **no caben**
en ninguna máquina gratuita.

**Repositorio HF (público, sin token):** `https://huggingface.co/JeanCoder/jean-models`
— todos los archivos responden HTTP 200 anónimos (verificado 2026-11-06).

---

## 2. Estado actual (2026-11-06)

### Funcionando y verificado
- **Codespace `jean-api-5g4g4qjg5r7p377jv`** (4 cores / 16 GB / 32 GB disco), modo
  *standard*: **Grey en :8888** y **Marvel en :8889** simultáneos, ambos a 128k.
- Test real: Grey `'ok'` en 8,4 s · Marvel `'Ok'` en 3,5 s · **401 correcto sin Bearer**.
- Los GGUF viven en el **workspace** (`/workspaces/jean-api/gguf/`) → los reinicios
  del Codespace ya **no re-descargan nada** ni llenan el disco.
- Modo persistente vía `.jean-mode` (`standard`|`fenix`) — sobrevive a rebuilds.
- OpenCode (tu PC): providers `jean-grey-api/grey` y `jean-marvel-api/marvel`
  (`limit.context = 131072`), clave vía `{env:JEAN_API_KEY}` (variable de entorno de
  usuario — nunca en archivos ni repos).

### Bloqueado / pendiente
- **Nada bloqueado.** El falso "incidente" de hoy fue culpa mía: en mis llamadas API
  escribí el dueño con una `e` de menos (`jeancodeer` en vez de `jeancodeeer`) y todo daba 404 —
  tu repo nunca dejó de existir. Corregido en 7 archivos con verificación numérica de
  la `e`, y los scripts ahora **derivan el owner de `GET /user`** (imposible volver a
  fallar por eso).
- **Recomendado (tranquilo, no urgente):** rotar el PAT y el token HF — nunca
  estuvieron en el repo, pero circularon en el chat. Después de rotar:
  `python tools/set_secrets.py` reinyecta los secrets del Codespace en 1 minuto.

## 3. Historia completa (cronología)

1. **Entrenamiento v0.7** (repo local `G:\LIFE IN DANGER\openjarvis-jean-grey`): merges
   LoRA→base Qwen3.5-27B, tags por modelo, y el sistema de evidencia
   (`scripts/kaggle/RUNLOG.md` como registro de la verdad).
2. **Distribución v1 — GitHub release** `v0.7-models` con assets en `.part`: funcionó
   peroConditional (descarga con `Accept: application/octet-stream`; `browser_download_url`
   da 404 en privados).
3. **Kaggle kernels CPU (2026-11-04/05)** — todo el pipeline de fusión+cuantización sin
   gastar cuota GPU. Cada fallo documentado: v4 (curl HTTP/2), v5 (targets cmake),
   v6 (formato `--lora`), v7 (splits no soportados en kernel), v8 (requantize),
   **v9 ÉXITO**: merge Q8_0+LoRA → `fenix Q4_K_M`. Luego kernel `q5`, kernel `lite`.
4. **Elección del modelo primario**: eval n=60 → Grey 0.4833 > Marvel 0.3667. Marvel
   deja de recibir más evals.
5. **Publicación en HF** (2026-11-05): 7 archivos públicos verificados anónimamente.
6. **128k real**: verificado en vivo que `-c 131072` + KV q8_0 permite grey+marvel
   simultáneos con margen; configuraciones permanentes en serve.sh + opencode.jsonc.
7. **Integración OpenCode** en el PC (providers con límites 131072/8192).
8. **Saga del 401 (2026-11-06)** — la más instructiva: el Codespace recicla contenedores
   (borra `/tmp` y `$HOME`; *el workspace sobrevive*); GGUF en `$HOME` se perdían y se
   re-descargaban hasta **llenar el disco** (32 GB); con disco lleno los downloads mueren
   (`curl 23`), ningún servidor arranca y el proxy de GitHub responde **401 con cuerpo
   vacío a todo** (esa era la confusión). Fixes estructurales: GGUF al workspace,
   modo persistente, log persistente. También hallazgo: 8 GiB duplicados entre $HOME y
   workspace del Fénix-lite.
9. **Tests de Fénix-lite en 16 GB (mismo día)**: IQ4_XS (14,15 GiB) no carga estable;
   IQ3_M (11,72 GiB) carga y escucha pero **~100 s/token** (RAM insuficiente, el
   servidor relee pesos del disco de red). Conclusión definitiva: **Fénix no es
   servible en el free tier de GitHub**; se borró del workspace (reversible desde HF).
10. **Reinicio frío limpio (2026-11-06, cierre)**: stop+start → sin re-descargas,
    Grey 8,4 s / Marvel 3,5 s → el pipeline es estable.
11. **Incidente repo + esta limpieza/reorganización** (2026-11-06): repo ocultado por
    GitHub; aquí se reorganiza el repo y el PC, y se escribe este README.

---

## 4. Qué hace cada archivo (repo `jeancodeeeer/jean-api`)

```
jean-api/
├── README.md                 ← este archivo
├── AGENTS.md                 ← mapa rápido para IAs (leer primero)
├── serve.sh                  ← descarga el GGUF y lanza llama-server (puerto, ctx, KV)
├── .devcontainer/
│   ├── devcontainer.json     ← definición del contenedor (postCreate)
│   ├── prep.sh               ← preparación inicial (llama.cpp binario, deps)
│   ├── autostart.sh          ← arranque en boot: lee .jean-mode, lanza modelos,
│   │                           registra puertos vía SSH-ping, descarga a $ROOT/gguf
│   ├── watchdog.sh           ← vigila y relanza servidores caídos
│   ├── mode-fenix.sh         ← cambia el Codespace a modo Fénix-lite (:8890)
│   └── mode-standard.sh      ← vuelve a Grey+Marvel (:8888/:8889)
├── generator/
│   ├── jean-api-generator.sh ← generador de despliegue multiplataforma (RAM-aware)
│   └── jean-api-generator.ps1← gemelo PowerShell para Windows
├── oracle/
│   └── setup-vm.sh           ← despliegue systemd en una VM ≥32 GB (Oracle A1 u otra)
├── tools/
│   ├── check_lora.py         ← valida cabeceras/integridad de un LoRA .gguf
│   ├── gguf_info.py          ← lee cabeceras GGUF (dims u64, strings hasta 64 MiB)
│   ├── split_gguf.py         ← divide GGUF en .part (distribución antigua)
│   └── set_secrets.py        ← setea secrets de Codespaces (sanitizado: solo env vars)
├── tests/
│   ├── test_ctx.sh           ← verifica el contexto real (-c 131072 en el cmdline)
│   ├── test_fenix_lite.sh    ← protocolo del test de Fénix-lite (estado+inferencia)
│   ├── test_github_source.sh ← descarga desde release con octet-stream
│   ├── fenix_test1.sh        ← test rápido de estado+inferencia en :8890
│   ├── probe_asset.sh        ← sondea URL de asset de release
│   └── diag.sh               ← diagnóstico post-boot del Codespace (logs/env/procesos)
├── .gitignore                ← gguf/, .jean-mode, key-*.txt, *.part, logs/, __pycache__
└── .gitattributes
```

**En vivo dentro del Codespace:** `serve.sh` ejecuta
`/home/vscode/llama/llama-b12110/llama-server -m gguf/<modelo>.gguf -c 131072
-ctk q8_0 -ctv q8_0 --port <p>` con auth Bearer `JEAN_API_KEY`.

---

## 5. Cómo usar (tu PC como cliente)

### Control del Codespace `D:\jean-work\jean-api.ps1` (exige `$env:GH_TOKEN`)

| comando | qué hace |
|---|---|
| `.\jean-api.ps1 start` | despierta el Codespace + ping SSH (registra puertos) |
| `.\jean-api.ps1 stop` | apaga (no gasta horas-core) |
| `.\jean-api.ps1 urls` | imprime las 2 URLs estables |
| `.\jean-api.ps1 test` | test grey+marvel+401 (espera carga) |
| `.\jean-api.ps1 status` | estado del Codespace |
| `.\jean-api.ps1 fenix-mode` | cambia a Fénix-lite :8890 (persistente) |
| `.\jean-api.ps1 standard-mode` | vuelve a Grey+Marvel |

### Endpoints (OpenAI-compatible)

```
Grey   https://jean-api-5g4g4qjg5r7p377jv-8888.app.github.dev/v1
Marvel https://jean-api-5g4g4qjg5r7p377jv-8889.app.github.dev/v1
Fénix  https://jean-api-5g4g4qjg5r7p377jv-8890.app.github.dev/v1   (solo en modo fenix)
```

```bash
curl -s $BASE/chat/completions -H "Authorization: Bearer $JEAN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"hola"}]}'
```

Las URLs **caducan si el Codespace duerme → 404**: usa `.\jean-api.ps1 start` para
despertarlo. Desde OpenCode los providers están preconfigurados: elige
`jean-grey-api/grey` o `jean-marvel-api/marvel` y reinicia OpenCode.

### En otra máquina (generador)

`generator/jean-api-generator.sh|ps1` genera el setup para cualquier host Linux/WSL/
Mac RAM-aware (≥20 GB → 128k · ≥12 GB → 64k · resto → 8k) y con `-Model fenix` para el
mono-servicio Fénix. `oracle/setup-vm.sh` deja todo como servicio systemd en una VM.

---

## 6. Mapa fisico del proyecto: donde esta TODO (PC + nube)

### Carpetas del PC
```
D:\jean-work\          <- hub de operacion: README/AGENTS, jean-api.ps1, push_all.ps1,
   |                        jean_api_key.txt, codespaces-jean\ (espejo del repo),
   |                        kaggle\ (3 kernels + logs out4..out9), generator\,
   |                        archive\ (experimentos cerrados)
D:\jean-work\fenix-gguf\  <- base Qwen3.5-27B-Q4_K_M.gguf (15,65 GB)
D:\ollama_models\         <- copia local en Ollama de grey+marvel v0.7 (6,9 GB)
G:\LIFE IN DANGER\openjarvis-jean-grey\   <- REPO DE ENTRENAMIENTO (datasets, LoRA, models/, persona/, RUNLOG)
G:\LIFE IN DANGER\tools\llama.cpp\      <- fuente de llama.cpp (los builds se regeneran de ahi)
C:\Users\ferna\.config\opencode\opencode.jsonc  <- providers jean-grey-api / jean-marvel-api
```
Este mapa tambien vive como codigo en `tools/project_map.py` (lo parsea graphify).

### Donde viven los pesos (los 8 GGUF)
- **Fuente canonica: HF publico** `https://huggingface.co/JeanCoder/jean-models` — los 7
  archivos .gguf de los modelos Jean responden 200 anonimos (verificado 2026-11-07:
  grey 2.52 · marvel 4.36 · fenix Q4 15.41 · Q5 17.91 · lite IQ3 11.72 · IQ4 14.15 · lora 0.59).
- **Copias locales**: grey+marvel tambien estan en el store de Ollama
  (`D:\ollama_models`, 6,9 GB) y en el workspace del Codespace (`/workspaces/jean-api/gguf/`).
- **Fenix completo/lite**: solo en HF (el PC de 8 GB y el Codespace de 16 GB no lo llevan).
- **Base** Qwen3.5-27B-Q4_K_M: solo en `D:\jean-work\fenix-gguf\`.

### Codespace (el servidor vivo)
- maquina `jean-api-5g4g4qjg5r7p377jv` (4c/16GB; checkout `/workspaces/jean-api`).
- llama-server: `/home/vscode/llama/llama-b12110/llama-server`.

### Enlaces web relevantes
- Perfil GitHub: https://github.com/jeancodeeer
- Repo del servicio/API: https://github.com/jeancodeeer/jean-api
- Otros repos: librecodigo · kanye-nest · Batch-IA (privado)
- Modelos (HF): https://huggingface.co/JeanCoder/jean-models · perfil https://huggingface.co/JeanCoder
- APIs vivas: grey/marvel (ver §2) · grafo Graphify: https://github.com/Graphify-Labs/graphify

## 7. Seguridad

**Reglas de siempre:** ni URLs ni claves dentro del repo. Las claves viven en
*GitHub Codespace secrets* (se inyectan via `tools/set_secrets.py`, que lee los
valores **solo de variables de entorno**) o en archivos locales gitignored
(`key-*.txt`). El helper con tokens nunca llegó a subirse — el repo está limpio.

**Lección del día (2026-11-06):** el "repo oculto" nunca existió — mi diagnóstico
usaba el dueño mal escrito (una `e` de menos: `jeancodeer` en lugar de `jeancodeeer`) y producía
404 coherentes en todas las redes. Incorporado al repo: el owner se **deriva de la
API** (`GET /user`) y la ortografía se verifica numéricamente (conteo e-runs).

**Credenciales:** el PAT y el token HF circularon en texto de chat (nunca en repo
ni logs), así que rotarlos es la práctica recomendada — cuando quieras. Después de
rotarlos, `tools/set_secrets.py` actualiza los secrets del Codespace y las APIs
siguen funcionando sin tocar nada más.

## 8. FAQ operativa

- **OpenCode da 401** → el Codespace está dormido o los puertos se des-registraron tras
  un reciclaje: `.\jean-api.ps1 start` (hace ping SSH que registra los puertos) y `test`.
- **503** → los servidores siguen cargando tras despertar (~2-4 min entre ambos);
  retestea.
- **¿Ctx real de 128k?** → dentro del Codespace: `bash tests/test_ctx.sh`.
- **¿Se pueden los 3 modelos a 128k a la vez?** → no en nube free: RAM 16 GB (KV 128k
  ≈ 2 GiB/modelo + pesos). Con 2 caben (funciona); para 3 hacen falta ≥ 48-64 GB.
- **¿Fénix en la nube gratis?** → solo Kaggle CPU (30 GB RAM, 12 h, sin cuota GPU) como
  experimento — pendiente. El full Q4_K_M cabe; la velocidad en 4 cores es por medir.
- **¿Cómo regenero el grafo (Graphify)?** → `pip install graphifyy` y `graphify .`
  (con `--code-only` no necesita LLM-key).
- **¿Y de dónde salen los "out4..out9"?** → outputs de los kernels Kaggle, evidencia
  cruda de cada pasada de merge/cuantización.

## 9. Roadmap

1. Rotar credenciales (PAT + token HF) y reinyectar secrets del Codespace con
   `tools/set_secrets.py`.
2. (Opcional) borrar el espejo `jean-api-mirror` en GitHub (1 clic; quedó de
   la falsa alarma y la API me lo deniega por scope).
3. Experimento Fénix-full en Kaggle CPU con túnel temporal (sin cuota GPU, sin tarjeta).
4. (Opcional) Oracle A1 ≥32 GB si decides pasar la verificación de identidad.
5. (Opcional) migrar el Codespace a 2 cores → ~60 h/mes.
