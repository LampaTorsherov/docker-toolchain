FROM debian:12

# Обновляем и устанавливаем ca-certificates
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
    libkrb5-3 \
    krb5-user \
    libgssapi-krb5-2 \
    ca-certificates \
    curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
