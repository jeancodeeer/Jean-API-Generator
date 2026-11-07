"""Setea secrets de GitHub Codespaces (cifrado sealed-box como exige la API).

SIN secretos en el codigo: TODOS los valores se leen de variables de entorno.
(asi historizamos un incidente: este archivo tenia tokens hardcodeados y el
repo, al volver publico, fue ocultado por GitHub)

Uso (PowerShell):
  $env:JEAN_GH_PAT       = "ghp_UN_PAT_CON_permisos_repo_y_admin_codespaces"
  $env:SOURCE_HF_TOKEN   = "hf_xxx"
  $env:SOURCE_GH_PAT     = "ghp_xxx"   # el que recibira el secret GH_PAT
  $env:SOURCE_JEAN_API_KEY = Get-Content D:\\jean-work\\jean_api_key.txt -Raw
  C:\\Python314\\python.exe tools/set_secrets.py
"""

import base64
import json
import os
import sys
import urllib.request

from nacl.public import PublicKey, SealedBox

TOKEN = os.environ.get("JEAN_GH_PAT")
OWNER = api("/user")["login"]  # derivado: imposible el typo


SECRETS = {
    "HF_TOKEN": os.environ.get("SOURCE_HF_TOKEN"),
    "JEAN_API_KEY": os.environ.get("SOURCE_JEAN_API_KEY"),
    "GH_PAT": os.environ.get("SOURCE_GH_PAT"),
}

_missing = [k for k, v in SECRETS.items() if not v]
if not TOKEN or _missing:
    sys.exit(
        "Faltan variables de entorno. Define JEAN_GH_PAT y "
        + ", ".join(sorted(_missing))
        + " (los valores SOURCE_* son lo que se guardara como secret)."
    )


def api(path, method="GET", body=None):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        method=method,
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Accept": "application/vnd.github+json"},
    )
    if body is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(body).encode()
    with urllib.request.urlopen(req) as r:
        raw = r.read()
        return json.loads(raw) if raw.strip() else {}


def main():
    pk = api(f"/repos/{OWNER}/codespaces/secrets/public-key")
    pub = PublicKey(base64.b64decode(pk["key"]))
    box = SealedBox(pub)
    for name, value in SECRETS.items():
        enc = base64.b64encode(box.encrypt(value.encode())).decode()
        api(
            f"/repos/{OWNER}/codespaces/secrets/{name}",
            method="PUT",
            body={"encrypted_value": enc, "key_id": pk["key_id"]},
        )
        print(f"secret {name} listo")


if __name__ == "__main__":
    main()
