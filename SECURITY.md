# Security policy

## Reporting a vulnerability
Please **do not open a public issue** for security problems. Use GitHub's private
reporting: *Security → Report a vulnerability* on this repository.

## Project rules
- No API keys, tokens or tunnel URLs in the repository. Secrets go through environment
  variables (`JEAN_API_KEY`, `HF_TOKEN`) or Kaggle Secrets; the launcher never prints a key
  you set yourself.
- The API must always run with `--api-key`; an unauthenticated request must return `401`
  (only `/health` is public, and it reveals nothing about the system).
- If a token has been exposed anywhere, rotate it and re-inject the secrets.
