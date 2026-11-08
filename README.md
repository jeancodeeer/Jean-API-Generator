<div align="center">

<img src="assets/social-preview.svg" alt="jean-api: Jean GGUF models served as an OpenAI-compatible API with llama.cpp on GitHub Codespaces" width="760">

# jean-api

**Serve the Jean v0.7 GGUF models as a free, OpenAI-compatible API with `llama.cpp`'s `llama-server`, running on a GitHub Codespace (CPU only).**

[![Models on Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97%20models-JeanCoder%2Fjean--models-yellow)](https://huggingface.co/JeanCoder/jean-models)
[![llama.cpp](https://img.shields.io/badge/powered%20by-llama.cpp-blue)](https://github.com/ggml-org/llama.cpp)
![OpenAI compatible](https://img.shields.io/badge/API-OpenAI--compatible-412991)
![Shell](https://img.shields.io/badge/scripts-bash%20%7C%20PowerShell%20%7C%20Python-4EAA25)
[![Open in GitHub Codespaces](https://img.shields.io/badge/Codespaces-open-181717?logo=github)](https://codespaces.new/jeancodeeer/jean-api)

English · [Español](README.es.md)

</div>

---

## What is this?

`jean-api` is the deployment layer for the **Jean v0.7** models (**Grey**, **Marvel** and **Fénix**, fine-tuned from Qwen3.5-27B and published as GGUF on Hugging Face). It turns a GitHub Codespace into a self-hosted LLM inference server that speaks the **OpenAI API** (`/v1/chat/completions`, `/v1/models`), so any OpenAI-compatible client, editor or coding agent can use the models by changing only the base URL and the API key.

Nothing runs on your own computer: your machine is just an HTTP client.

## Features

What the code in this repository actually does:

- **`llama-server` per model** – `serve.sh {grey|marvel|fenix}` downloads the GGUF and starts `llama-server` with Bearer-token authentication (`--api-key`).
- **128k context on CPU** – models are started with `-c 131072` and a quantized KV cache (`-ctk q8_0 -ctv q8_0`). Native context of the GGUFs is 262144.
- **Two models side by side** – Grey on `:8888` and Marvel on `:8889` fit together in a 16 GB Codespace at 128k context (see [docs/HISTORY.md](docs/HISTORY.md) for the measurements and for what does *not* fit).
- **Auto-start and recovery** – `.devcontainer/autostart.sh` starts the servers when the Codespace boots, gated by available RAM; `watchdog.sh` checks every 60 s and relaunches a server that stopped answering.
- **Persistent mode switch** – `.jean-mode` (`standard` or `fenix`) selects which models run and survives rebuilds; GGUF files live in the workspace (`gguf/`) so restarts don't re-download them.
- **Optional Cloudflare quick tunnels** – `cloudflared` is installed on demand as a fallback public URL.
- **Run it elsewhere** – `generator/` (bash and PowerShell) starts the same stack on a local Linux/macOS/WSL/Windows host with RAM-aware context (≥ 20 GB → 128k, ≥ 12 GB → 64k, otherwise 8k); `oracle/setup-vm.sh` installs it as a **systemd** service on an Ubuntu/Debian VM.
- **Windows control script** – `jean-api.ps1 start|stop|urls|test|status|fenix-mode|standard-mode` wakes, tests and switches the Codespace through the `gh` CLI.
- **Helper tools** – `tools/` has a GGUF header reader, a LoRA integrity check, a GGUF splitter and a script that sets Codespaces secrets from environment variables only.

## The models

Weights are public on Hugging Face: **[JeanCoder/jean-models](https://huggingface.co/JeanCoder/jean-models)** (no token needed to download).

| Model | Served as | Role | GGUF | Size |
|---|---|---|---|---|
| Jean Grey | `jean-grey` (`:8888`) | primary code model | `jean-grey-v0.7.Q4_K_M.gguf` | 2.52 GiB |
| Jean Marvel | `jean-marvel` (`:8889`) | agent / second opinion | `jean-marvel-v0.7.Q4_K_M.gguf` | 4.36 GiB |
| Jean Fénix | `jean-fenix` (`:8890`) | large model (Qwen3.5-27B + LoRA) | `jean-fenix-v0.7.Q4_K_M.gguf` (+ Q5_K_M, lite IQ4_XS / IQ3_M, LoRA adapter) | 15.41 GiB (Q4_K_M) |

> **Fénix needs more RAM than a free Codespace has.** On 16 GB, the lite IQ3_M variant loads but generates at roughly 100 s per token (measured). Run Fénix on a machine with ≥ 32 GB (see `oracle/` and `generator/`).

## Quick start (GitHub Codespaces)

1. **Create a Codespace** from this repository ([open it here](https://codespaces.new/jeancodeeer/jean-api)). The dev container installs `llama.cpp` (prebuilt CPU binary) and prepares the models.
2. **Add Codespaces secrets** (repository or user level):
   - `JEAN_API_KEY` – the Bearer key your clients must send (you choose it).
   - `HF_TOKEN` – a Hugging Face token (`serve.sh` requires it for Grey and Marvel; Fénix downloads anonymously).
3. **Start / restart the Codespace.** `postStartCommand` runs `.devcontainer/autostart.sh`, which launches Grey on `:8888` and, with ≥ 14 GB RAM, Marvel on `:8889`.
4. **Make the ports reachable.** Port 8888/8889 must be forwarded as *public* (the API key protects them). If `GH_PAT` is set as a secret, the Codespace also records its Cloudflare fallback URLs in `~/logs/urls.txt`.

You can also run a single model by hand inside the Codespace:

```bash
export JEAN_API_KEY=choose-a-long-random-key
export HF_TOKEN=hf_...
PORT=8888 bash serve.sh grey
```

## Usage

Any OpenAI-compatible client works. With `curl`:

```bash
BASE="https://<your-forwarded-8888-url>/v1"

curl -s "$BASE/chat/completions" \
  -H "Authorization: Bearer $JEAN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"jean-grey","messages":[{"role":"user","content":"Write a Python function that reverses a string."}]}'
```

With the OpenAI Python SDK:

```python
from openai import OpenAI

client = OpenAI(base_url="https://<your-forwarded-8888-url>/v1", api_key="<JEAN_API_KEY>")
r = client.chat.completions.create(
    model="jean-grey",
    messages=[{"role": "user", "content": "Explain what a mutex is in two sentences."}],
)
print(r.choices[0].message.content)
```

A request without the Bearer header returns `401`. A `503` right after waking the Codespace means the model is still loading (about 2–4 minutes for both).

### Control script for Windows

```powershell
$env:GH_TOKEN = "<a PAT able to manage your codespaces>"   # never commit this
.\jean-api.ps1 start          # wake the Codespace, register ports, print URLs
.\jean-api.ps1 test           # list models, run one chat per model, check that no-key gives 401
.\jean-api.ps1 fenix-mode     # switch to Fénix-lite on :8890 (persistent)
.\jean-api.ps1 standard-mode  # back to Grey + Marvel
.\jean-api.ps1 stop           # stop the Codespace
```

It looks for `gh` in `PATH` (override with `GH_CLI`) and reads the key from `jean_api_key.txt` next to the script (override with `JEAN_API_KEY_FILE`).

### Run on your own machine or VM

```bash
./generator/jean-api-generator.sh start grey            # Linux / macOS / WSL
sudo bash oracle/setup-vm.sh --model fenix --api-key "…" # systemd service on Ubuntu/Debian
```

## Project structure

```
jean-api/
├── serve.sh                 # download GGUF + launch llama-server (single source of server flags)
├── jean-api.ps1             # Windows control script (gh CLI)
├── .devcontainer/           # Codespaces: prep, autostart, watchdog, mode switches
├── generator/               # RAM-aware launchers for Linux/macOS/WSL (sh) and Windows (ps1)
├── oracle/setup-vm.sh       # systemd install on a VM
├── tools/                   # GGUF/LoRA utilities, Codespaces secrets helper, project map
├── tests/                   # context (128k) check, diagnostics, Fénix-lite probes
├── docs/HISTORY.md          # measurements, failed attempts and design decisions
└── graphify-out/            # code knowledge graph (generated with graphify)
```

## Limits worth knowing

- A Codespace sleeps when idle; the forwarded URLs stop answering until it is woken again.
- Free Codespaces are CPU-only with 16 GB RAM: expect small-model speeds, not GPU speeds. Measured example: a one-word answer took 8.4 s on Grey and 3.5 s on Marvel.
- Three models at 128k simultaneously do not fit in 16 GB.

## Roadmap

Derived from the current state of the repository (see [docs/HISTORY.md](docs/HISTORY.md)):

- Serve Fénix on a ≥ 32 GB host (VM or Kaggle CPU kernel) – the only thing the free tier cannot do.
- Rotate and re-inject Codespaces secrets with `tools/set_secrets.py` after any token exposure.

## Security

Secrets are passed only through environment variables or Codespaces secrets; never commit keys or Codespace URLs. See [SECURITY.md](SECURITY.md).

## Contributing

Issues and pull requests are welcome – see [CONTRIBUTING.md](CONTRIBUTING.md). The server flags live only in `serve.sh`; please don't duplicate them.

## License

No license file has been published yet, so by default all rights are reserved. The Jean model weights are derived from [Qwen3.5-27B](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF); check the upstream licence before redistributing them.

## Credits

- [llama.cpp](https://github.com/ggml-org/llama.cpp) (`llama-server`) by ggml-org.
- Qwen3.5-27B GGUF base by Qwen / [Unsloth](https://huggingface.co/unsloth/Qwen3.5-27B-GGUF).
- [Cloudflare quick tunnels](https://github.com/cloudflare/cloudflared) as optional fallback.
- [graphify](https://github.com/Graphify-Labs/graphify) for the code graph in `graphify-out/`.
