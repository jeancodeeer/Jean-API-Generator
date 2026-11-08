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
bash -n serve.sh .devcontainer/*.sh generator/*.sh oracle/setup-vm.sh   # syntax check
bash tests/test_ctx.sh      # inside a Codespace: verifies the 128k context
bash tests/diag.sh          # inside a Codespace: processes, logs, disk
```
