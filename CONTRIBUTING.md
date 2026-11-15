# Contributing

Issues and pull requests are welcome.

## Ground rules
- **No secrets or private URLs** in commits; pass them via environment variables.
- `serve.sh` is the single source of truth for `llama-server` flags (`-c 131072`, `-ctk/-ctv q8_0`).
  Don't change them without re-measuring RAM, and don't duplicate that logic elsewhere.
- Keep scripts bash (`set -u`) or PowerShell 5+, and idempotent where possible.
- Report what you actually measured (RAM, latency) in the PR description.

## Checking your change
```bash
bash -n serve.sh generator/*.sh oracle/setup-vm.sh   # syntax check
python tests/test_router.py                          # router
python -m unittest tests.test_launch                 # launcher: ports and GPUs per model
bash tests/e2e_launch.sh                             # the real thing on Linux/WSL: small model, no tunnel
bash tests/test_ctx.sh      # on a machine with >= 16 GB: verifies the 128k context
```
