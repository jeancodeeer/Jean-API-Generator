# Security policy

## Reporting a vulnerability
Please **do not open a public issue** for security problems. Use GitHub's private
reporting: *Security → Report a vulnerability* on this repository.

## Project rules
- No API keys, tokens or Codespace URLs in the repository. Secrets go through environment
  variables or Codespaces secrets (`tools/set_secrets.py` reads values only from the environment).
- The API must always run with `--api-key`; an unauthenticated request must return `401`
  (`jean-api.ps1 test` checks this).
- If a token has been exposed anywhere, rotate it and re-inject the secrets.
