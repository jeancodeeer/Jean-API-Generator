# jean-api

API compatible con OpenAI (llama.cpp) que sirve los modelos **Jean v0.7** desde
un GitHub Codespace, sin GPU y sin tarjeta.

## Modelos

| alias | composición | tamaño | contexto | notas |
|---|---|---|---|---|
| `jean-grey` | `jean-grey-v0.7.Q4_K_M.gguf` | 2.52 GiB | 16k | **primario** — eval n=60: 0.4833 |
| `jean-marvel` | `jean-marvel-v0.7.Q4_K_M.gguf` | 4.06 GiB | 8k | eval n=60: 0.3667 |
| `jean-fenix` | `Qwen3.5-27B-Q4_K_M` + LoRA Jean | 15.6 GiB + 0.6 GiB | 4k | necesita ≥ 32 GB RAM; no entra en el free tier |

Los dos primeros corren **a la vez** en la máquina `standardLinux32gb`
(4 cores / 16 GB): Grey en `:8888`, Marvel en `:8889`.

## Endpoints

```
POST https://<url-publica>/v1/chat/completions
GET  https://<url-publica>/v1/models
Authorization: Bearer $JEAN_API_KEY
```

La URL pública la publica el propio Codespace en [`logs/status.md`](logs/status.md)
(túnel de Cloudflare) junto con un self-test de cada puerto.

## Dónde viven los pesos

1. **Hugging Face** (privado): `JeanCoder/jean-models`
   - `jean-grey-v0.7.Q4_K_M.gguf`
   - `jean-marvel-v0.7.Q4_K_M.gguf`
   - `jean-fenix-v0.7.lora.gguf`
2. **GitHub Release** `v0.7-models` (espejo): cada modelo partido en trozos
   < 2 GiB + `*.manifest.json` con sha256 por parte y sha256 total.

```bash
cat jean-grey-v0.7.Q4_K_M.part* > jean-grey-v0.7.Q4_K_M.gguf
sha256sum jean-grey-v0.7.Q4_K_M.gguf   # comparar con el manifest
```

Fenix no se distribuye como GGUF fusionado: se sirve como
`unsloth/Qwen3.5-27B-GGUF` (base pública) + `jean-fenix-v0.7.lora.gguf`
(`llama-server -m base.gguf --lora lora.gguf`).

## Arranque / parada

El Codespace arranca la API solo (`postStartCommand` → `.devcontainer/autostart.sh`).

```bash
gh codespace list
gh codespace stop -c <nombre>
# arrancar:
gh api -X POST /user/codespaces/<nombre>/start
```

Secrets necesarios (Codespaces → Settings → Secrets):

| secret | para qué |
|---|---|
| `HF_TOKEN` | bajar los GGUF del repo privado |
| `JEAN_API_KEY` | clave Bearer que exige la API |
| `GH_PAT` | publicar `logs/status.md` (depuración sin SSH) |

## Ficheros

- `serve.sh` — descarga el modelo y lanza `llama-server`.
- `.devcontainer/prep.sh` — postCreate: pre-descarga modelos + binario.
- `.devcontainer/autostart.sh` — postStart: arranca modelos, túneles y status.
- `logs/status.md` — estado, URLs públicas y self-test.
