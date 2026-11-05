"""Info de cabecera GGUF: version, tensores declarados vs leidos, arch.

Uso: python gguf_info.py <fichero.gguf> [mas.gguf ...]
"""

import os
import sys

from check_lora import read_tensor_table

for p in sys.argv[1:]:
    try:
        ver, meta, tensors, n = read_tensor_table(p)
        print(f"{p}")
        print(f"  {os.path.getsize(p)/2**30:.2f} GiB | gguf v{ver}"
              f" | {n} tensores declarados, {len(tensors)} leidos"
              f" | arch={meta.get('general.architecture')}"
              f" | name={meta.get('general.name')}"
              f" | file_type={meta.get('general.file_type')}")
    except Exception as e:  # noqa: BLE001 - informe, no fallo en cadena
        print(f"{p}")
        print(f"  ERROR: {type(e).__name__}: {e}")
