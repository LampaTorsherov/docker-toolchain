FROM golang:1.26-bookworm

# Устанавливаем зависимости для сборки с Kerberos
RUN apt update && apt upgrade -y && \
    apt install -y \
        libkrb5-dev \
        krb5-config \
        pkg-config \
        gcc \
        g++ \
        make \
        && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
