# Jean API en Hugging Face Spaces (hardware gratuito "CPU basic": 2 vCPU, 16 GB de RAM).
# Este archivo es todo lo que necesita tu Space: clona Jean-API-Generator y arranca
# Jean Grey (:8888) y Jean Marvel (:8889) detrás del router OpenAI-compatible en :7860.
#
# La clave va en Settings → Variables and secrets → New secret: JEAN_API_KEY.
# Sin ella el Space no arranca (nunca sirve los modelos sin autenticación).

# llama-server oficial de llama.cpp, compilado para CPU
FROM ghcr.io/ggml-org/llama.cpp:server

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 git curl ca-certificates procps \
 && rm -rf /var/lib/apt/lists/*

# rama o tag de Jean-API-Generator ("Factory rebuild" en Settings para actualizar)
ARG JEAN_REF=main
RUN git clone --depth 1 -b "$JEAN_REF" https://github.com/jeancodeeer/Jean-API-Generator.git /opt/jean \
 && mkdir -p /opt/jean/gguf /opt/jean-home \
 && chown -R 1000:1000 /opt/jean /opt/jean-home

# Hugging Face ejecuta el contenedor con el usuario 1000
USER 1000
ENV HOME=/opt/jean-home \
    JEAN_LLAMA_BIN=/app/llama-server \
    LD_LIBRARY_PATH=/app \
    JEAN_CONTROL_PORT=7860 \
    JEAN_SLOTS=8888:grey,8889:marvel \
    JEAN_CTX=32768 \
    JEAN_THREADS=2
WORKDIR /opt/jean
EXPOSE 7860

# la imagen base vigila el puerto 8080; aquí el que importa es 7860
HEALTHCHECK NONE
ENTRYPOINT []
CMD ["bash", "space/start.sh"]
