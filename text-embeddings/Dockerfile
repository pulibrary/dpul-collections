FROM lukemathwalker/cargo-chef:latest-rust-1.85-bookworm AS chef
WORKDIR /usr/src

ENV SCCACHE=0.10.0
ENV RUSTC_WRAPPER=/usr/local/bin/sccache

# Download, configure sccache
RUN curl -fsSL https://github.com/mozilla/sccache/releases/download/v$SCCACHE/sccache-v$SCCACHE-x86_64-unknown-linux-musl.tar.gz | tar -xzv --strip-components=1 -C /usr/local/bin sccache-v$SCCACHE-x86_64-unknown-linux-musl/sccache && \
    chmod +x /usr/local/bin/sccache

FROM alpine/git:latest AS project_files

RUN mkdir /project_files
WORKDIR /project_files
RUN git clone --branch main --depth 1 https://github.com/huggingface/text-embeddings-inference.git

FROM chef AS planner

COPY --from=project_files /project_files/text-embeddings-inference/backends backends
COPY --from=project_files /project_files/text-embeddings-inference/core core
COPY --from=project_files /project_files/text-embeddings-inference/router router
COPY --from=project_files /project_files/text-embeddings-inference/Cargo.toml ./
COPY --from=project_files /project_files/text-embeddings-inference/Cargo.lock ./

RUN cargo chef prepare  --recipe-path recipe.json

FROM chef AS builder

ARG GIT_SHA
ARG DOCKER_LABEL

# sccache specific variables
ARG SCCACHE_GHA_ENABLED

# Install build dependencies without Intel MKL for AMD compatibility
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    libomp-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=planner /usr/src/recipe.json recipe.json

# Build without Intel MKL feature for AMD CPU compatibility
RUN cargo chef cook --release --features ort,candle --no-default-features --recipe-path recipe.json && sccache -s

COPY --from=project_files /project_files/text-embeddings-inference/backends backends
COPY --from=project_files /project_files/text-embeddings-inference/core core
COPY --from=project_files /project_files/text-embeddings-inference/router router
COPY --from=project_files /project_files/text-embeddings-inference/Cargo.toml ./
COPY --from=project_files /project_files/text-embeddings-inference/Cargo.lock ./

FROM builder AS http-builder

RUN cargo build --release --bin text-embeddings-router --features ort,candle,http --no-default-features && sccache -s

FROM builder AS grpc-builder

RUN PROTOC_ZIP=protoc-21.12-linux-x86_64.zip && \
    curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v21.12/$PROTOC_ZIP && \
    unzip -o $PROTOC_ZIP -d /usr/local bin/protoc && \
    unzip -o $PROTOC_ZIP -d /usr/local 'include/*' && \
    rm -f $PROTOC_ZIP

COPY --from=project_files /project_files/text-embeddings-inference/proto proto

RUN cargo build --release --bin text-embeddings-router --features ort,candle,grpc --no-default-features && sccache -s

FROM debian:bookworm-slim AS base

# Environment variables without Intel MKL specific settings
ENV HUGGINGFACE_HUB_CACHE=/data \
    PORT=80 \
    RAYON_NUM_THREADS=8

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libomp-dev \
    ca-certificates \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

FROM base AS grpc

COPY --from=grpc-builder /usr/src/target/release/text-embeddings-router /usr/local/bin/text-embeddings-router

ENTRYPOINT ["text-embeddings-router"]
CMD ["--json-output"]

FROM base AS http

COPY --from=http-builder /usr/src/target/release/text-embeddings-router /usr/local/bin/text-embeddings-router

# Amazon SageMaker compatible image
FROM http AS sagemaker
COPY --chmod=775 sagemaker-entrypoint.sh entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]

# Default image
FROM http

ENTRYPOINT ["text-embeddings-router"]
CMD ["--json-output"] 
