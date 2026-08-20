# syntax=docker/dockerfile:1.7
FROM python:3.13-slim-bookworm

ARG BC_CODE_ATLAS_REPOSITORY=https://github.com/StefanMaron/bc-code-atlas.git
ARG BC_CODE_ATLAS_REF=master

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_NO_PROGRESS=1 \
    PATH=/root/.local/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash build-essential ca-certificates curl git libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.8.13 /uv /uvx /usr/local/bin/

WORKDIR /app

RUN git init \
    && git remote add origin "$BC_CODE_ATLAS_REPOSITORY" \
    && git fetch --depth 1 origin "$BC_CODE_ATLAS_REF" \
    && git checkout --detach FETCH_HEAD \
    && git submodule update --init --recursive --depth 1 \
        tools/cocoindex-code tools/graphify-al tools/tree-sitter-al \
    && cp -a data /opt/bcatlas-data-seed

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --project tools/cocoindex-code --frozen \
    && uv sync --project chunker \
    && uv sync --project aggregator --frozen \
    && uv sync --project registry --frozen \
    && uv sync --project build --frozen \
    && uv sync --project tools/graphify-al --extra al --extra mcp --frozen

COPY entrypoint.sh bootstrap.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/bootstrap.sh \
    && mkdir -p /app/data /root/.cache/huggingface /root/.cocoindex_code

EXPOSE 8800
HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --retries=5 \
  CMD python -c "import socket; s=socket.create_connection(('127.0.0.1',8800),5); s.close()"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
