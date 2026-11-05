"""Comprueba que un LoRA GGUF encaja con su modelo base.

Lee solo la cabecera y la tabla de tensores (los pesos no se tocan), asi que
va rapido incluso con ficheros de 40 GB.

Nota: en la tabla de tensores GGUF, las dimensiones son u64[n_dims] (longitud
variable); leerlas como un unico u64 desincroniza el parser y acaba en
MemoryError. Ese era el bug de la primera version de este script.

Uso: python check_lora.py <base.gguf> <lora.gguf>
"""

import os
import struct
import sys

GGUF_MAGIC = b"GGUF"

# tipos de valor GGUF
(U8, I8, U16, I16, U32, I32, F32, BOOL, STRING, ARRAY, U64, I64, F64) = range(13)

MAX_STRING = 64 << 20  # cap sanitario; las plantillas de chat llegan a varios KiB


class Reader:
    def __init__(self, f):
        self.f = f

    def read(self, n):
        b = self.f.read(n)
        if len(b) != n:
            raise EOFError("fin de fichero inesperado")
        return b

    def u32(self):
        return struct.unpack("<I", self.read(4))[0]

    def u64(self):
        return struct.unpack("<Q", self.read(8))[0]

    def string(self):
        n = self.u64()
        if n > MAX_STRING:
            raise ValueError(f"string de {n} bytes: parser sospecha desincronizacion")
        return self.read(n).decode("utf-8", "replace")

    def value(self, t):
        if t == U8:
            return self.read(1)[0]
        if t == I8:
            return struct.unpack("<b", self.read(1))[0]
        if t == U16:
            return struct.unpack("<H", self.read(2))[0]
        if t == I16:
            return struct.unpack("<h", self.read(2))[0]
        if t == U32:
            return self.u32()
        if t == I32:
            return struct.unpack("<i", self.read(4))[0]
        if t == F32:
            return struct.unpack("<f", self.read(4))[0]
        if t == BOOL:
            return bool(self.read(1)[0])
        if t == STRING:
            return self.string()
        if t == U64:
            return self.u64()
        if t == I64:
            return struct.unpack("<q", self.read(8))[0]
        if t == F64:
            return struct.unpack("<d", self.read(8))[0]
        if t == ARRAY:
            t2 = self.u32()
            n = self.u64()
            return [self.value(t2) for _ in range(n)]
        raise ValueError(f"tipo GGUF desconocido: {t}")


def read_tensor_table(path):
    """Devuelve (version, meta, {nombre: dims}, n_tensores) sin leer pesos."""
    with open(path, "rb") as f:
        r = Reader(f)
        if r.read(4) != GGUF_MAGIC:
            raise ValueError(f"{path}: no es un GGUF")
        version = r.u32()
        n_tensors = r.u64()
        n_kv = r.u64()
        meta = {}
        for _ in range(n_kv):
            k = r.string()
            t = r.u32()
            meta[k] = r.value(t)
        tensors = {}
        for _ in range(n_tensors):
            name = r.string()
            n_dims = r.u32()
            dims = [r.u64() for _ in range(n_dims)]  # u64[n_dims], longitud variable
            r.u32()  # tipo de tensor
            r.u64()  # offset
            tensors[name] = dims
    return version, meta, tensors, n_tensors


def lora_target(name):
    """blk.0.attn_q.weight.lora_a -> blk.0.attn_q.weight"""
    for suffix in (".lora_a", ".lora_b", ".lora_embd", ".lora"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return None


def main():
    base_path, lora_path = sys.argv[1], sys.argv[2]

    b_ver, b_meta, b_t, b_n = read_tensor_table(base_path)
    l_ver, l_meta, l_t, l_n = read_tensor_table(lora_path)

    print(f"base : {base_path} ({os.path.getsize(base_path)/2**30:.2f} GiB)")
    print(f"  gguf v{b_ver} | {b_n} tensores | arch={b_meta.get('general.architecture')}"
          f" | name={b_meta.get('general.name')}")
    print(f"lora : {lora_path} ({os.path.getsize(lora_path)/2**30:.2f} GiB)")
    print(f"  gguf v{l_ver} | {l_n} tensores | type={l_meta.get('general.type')}"
          f" | base={l_meta.get('general.base_model.name', '?')}"
          f" | alpha={l_meta.get('adapter.lora.alpha')}")

    base_set = set(b_t)
    targets = {}   # tensor objetivo -> [tensores lora que lo tocan]
    others = []
    for n in l_t:
        t = lora_target(n)
        if t is None:
            others.append(n)
            continue
        if t not in base_set and not t.endswith(".weight") and t + ".weight" in base_set:
            t = t + ".weight"  # estilo alternativo: blk.0.attn_q.lora_a -> ...attn_q.weight
        targets.setdefault(t, []).append(n)

    pairs = sum(1 for v in targets.values() if len(v) == 2)
    missing = sorted(t for t in targets if t not in base_set)
    print(f"\nobjetivos unicos: {len(targets)} | pares a/b: {pairs}"
          f" | tensores no-LoRA: {len(others)}")
    if others:
        print("  no-LoRA (muestra):", others[:5])
    print(f"objetivos AUSENTES en la base: {len(missing)}")
    for m in missing[:10]:
        print(f"  - {m}")

    if targets:
        t0 = sorted(targets)[0]
        print(f"\nejemplo '{t0}': base dims={b_t.get(t0)}")
        for n in sorted(targets[t0]):
            print(f"  {n}: dims={l_t[n]}")

    ok = bool(targets) and not missing
    print("\nRESULTADO:", "LoRA COMPATIBLE con la base" if ok else "INCOMPATIBLE")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
