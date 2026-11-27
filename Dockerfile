# syntax=docker/dockerfile:1.7

# Universal Patroni build environment (Debian 12 / glibc / amd64).
# Installs Python, Patroni, Nuitka and native toolchains globally.
# Intentionally does NOT create or populate a runtime output directory.

FROM --platform=linux/amd64 python:3.11.18-slim-bookworm

ARG PATRONI_VERSION=4.1.5
ARG NUITKA_VERSION=4.3.4

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Build tools and development headers for Nuitka and native Python extensions.
# Do not install Debian's python3-dev: this image already has a complete
# CPython installation (including matching headers) under /usr/local.
RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        binutils \
        clang \
        lld \
        llvm \
        ccache \
        patchelf \
        pkg-config \
        cmake \
        ninja-build \
        git \
        nano \
        file \
        ca-certificates \
        libffi-dev \
        libssl-dev \
        libpq-dev \
        libyaml-dev \
        libzstd-dev \
        libbz2-dev \
        liblzma-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses-dev \
        libgdbm-dev \
        libexpat1-dev \
        zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*

# Normal, globally installed Python packages. Nothing is relocated.
RUN set -eux; \
    python -m pip install \
        "patroni[etcd,etcd3,psycopg3]==${PATRONI_VERSION}" \
        'psycopg[binary]' \
        "Nuitka==${NUITKA_VERSION}" \
        zstandard \
        ordered-set; \
    python -m pip check; \
    python -c 'import patroni, patroni.dcs.etcd, patroni.dcs.etcd3, psycopg, psutil, nuitka, ssl, ctypes'; \
    patroni --version; \
    patronictl --help >/dev/null; \
    python -m nuitka --version

# Offline source for later, user-defined pip installs into any target prefix.
# Freeze the *installed* versions, then download/build matching wheels.
RUN set -eux; \
    mkdir -p /opt/wheelhouse; \
    python -m pip freeze --all > /opt/wheelhouse/requirements.lock; \
    python -m pip wheel \
        --wheel-dir=/opt/wheelhouse \
        -r /opt/wheelhouse/requirements.lock; \
    ls -lh /opt/wheelhouse/*.whl

WORKDIR /work
CMD ["/bin/bash"]
