FROM debian:12

# Обновляем и устанавливаем ca-certificates
RUN apt update && \
    apt upgrade && \
    apt install -y ca-certificates && \
    apt install -y curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
