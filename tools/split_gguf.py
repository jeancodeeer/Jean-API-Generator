"""Parte un GGUF en trozos < 2 GiB para subirlos como GitHub Release assets.

GitHub limita cada asset de release a 2 GiB y cada archivo de repo a 100 MB,
asi que los modelos se sirven como partes + manifest con sha256 para verificar
y reconstruir con `cat parte.* > modelo.gguf`.

Uso:  python split_gguf.py <archivo.gguf> <dir_salida> [tam_parte_MiB]
"""

import hashlib
import json
import os
import sys

DEFAULT_PART_MIB = 1800  # 1.8 GiB: margen bajo el limite de 2 GiB


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def split(src: str, outdir: str, part_mib: int) -> dict:
    size = os.path.getsize(src)
    part_bytes = part_mib * 1024 * 1024
    nparts = (size + part_bytes - 1) // part_bytes
    base = os.path.splitext(os.path.basename(src))[0]
    os.makedirs(outdir, exist_ok=True)

    parts = []
    with open(src, "rb") as f:
        for i in range(nparts):
            name = f"{base}.part{i:02d}"
            dst = os.path.join(outdir, name)
            remaining = min(part_bytes, size - f.tell())
            written = 0
            with open(dst, "wb") as g:
                while written < remaining:
                    buf = f.read(min(16 * 1024 * 1024, remaining - written))
                    if not buf:
                        break
                    g.write(buf)
                    written += len(buf)
            parts.append({"name": name, "bytes": written, "sha256": sha256_file(dst)})
            print(f"  {name}: {written / 1024**3:.2f} GiB")

    manifest = {
        "file": os.path.basename(src),
        "bytes": size,
        "sha256": sha256_file(src),
        "parts": parts,
        "reassemble": "cat " + " ".join(p["name"] for p in parts) + " > " + os.path.basename(src),
    }
    mpath = os.path.join(outdir, base + ".manifest.json")
    with open(mpath, "w", encoding="utf-8") as m:
        json.dump(manifest, m, indent=2)
    print(f"manifest: {mpath}")
    print(f"sha256 total: {manifest['sha256']}")
    return manifest


if __name__ == "__main__":
    src = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(src)
    part_mib = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_PART_MIB
    split(src, outdir, part_mib)
