# Historia y mediciones

Registro de decisiones y pruebas que explican por qué `jean-api` está configurado como está (fechas de 2026).

## Modelos y entrenamiento
- Familia v0.7 sobre Qwen3.5-27B: **Grey** y **Marvel** (pequeños) y **Fénix** (27B + LoRA).
- Los GGUF se publican en <https://huggingface.co/JeanCoder/jean-models> (Grey, Marvel, Fénix Q4_K_M / Q5_K_M / lite IQ4_XS / lite IQ3_M y el adaptador LoRA).
- La fusión LoRA→base y la cuantización se hicieron en kernels de Kaggle solo-CPU; su registro vive en el repositorio de entrenamiento, no aquí.

## Distribución
1. v1: *assets* de un GitHub Release partidos en `.part` con manifiesto sha256 (`serve.sh` aún soporta `JEAN_SOURCE=github`; en repos privados hay que descargar con `Accept: application/octet-stream`, porque `browser_download_url` da 404).
2. Actual: descarga directa desde Hugging Face.

## Contexto de 128k (medido)
- `-c 131072` + KV `q8_0` ≈ 2 GiB de KV por modelo. Grey + Marvel a la vez en 16 GB: ~12,3 de 16 GB usados (~3,7 GB libres).
- Tres modelos a 128k simultáneos no caben en ninguna máquina gratuita.
- Respuesta de prueba de una palabra: Grey 8,4 s · Marvel 3,5 s.

## La "saga del 401"
El Codespace recicla el contenedor y borra `/tmp` y `$HOME`; el *workspace* sobrevive. Los GGUF guardados en `$HOME` se re-descargaban hasta llenar el disco de 32 GB; con el disco lleno las descargas fallan, ningún servidor arranca y el proxy de GitHub responde **401 con cuerpo vacío**. Correcciones estructurales: GGUF en el workspace (`gguf/`), modo persistente (`.jean-mode`) y logs persistentes. Diagnóstico: `tests/diag.sh` dentro del Codespace.

## Fénix en 16 GB
- IQ4_XS (14,15 GiB): no carga estable. IQ3_M (11,72 GiB): carga, pero ~100 s/token porque el servidor relee pesos desde disco.
- Conclusión: Fénix necesita ≥ 32 GB (VM o kernel CPU de Kaggle).

## Nota sobre el propietario en las URLs
El propietario correcto en GitHub es `jeancodeeer` (tres «e» entre la «d» y la «r»). Una variante con una «e» de más (`jeancodeeeer`) estuvo en varios scripts y daba 404; ya está corregida. Los scripts nuevos no deben escribirlo a mano: el propietario se puede obtener con `gh api user --jq .login`.
