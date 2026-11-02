
# syntax=docker/dockerfile:1.7

ARG DEBIAN_VERSION=debian:12

# --- Этап 1: скачивание пакетов ---
FROM ${DEBIAN_VERSION} AS downloader

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app/packages

# Сохраняем .deb отдельно от стандартного кэша APT.
# Включаем зависимости curl и ca-certificates.
RUN set -eux; \
    mkdir -p /app/packages/partial; \
    apt-get update; \
    apt-get \
        -o Dir::Cache::archives=/app/packages \
        -o APT::Keep-Downloaded-Packages=true \
        install -y --no-install-recommends \
        ca-certificates curl

# Подключаем официальный репозиторий Docker.
RUN set -eux; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    printf 'Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
        "$VERSION_CODENAME" "$(dpkg --print-architecture)" \
        > /etc/apt/sources.list.d/docker.sources; \
    apt-get update

# Скачиваем Docker Engine, CLI, Buildx, Compose
# и все зависимости, отсутствующие в сборочном образе.
RUN set -eux; \
    apt-get \
        -o Dir::Cache::archives=/app/packages \
        -o APT::Keep-Downloaded-Packages=true \
        install -y --download-only --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin; \
    . /etc/os-release; \
    printf '%s\n' "$VERSION_CODENAME" \
        > /app/packages/.debian-codename; \
    dpkg --print-architecture \
        > /app/packages/.architecture

# Формируем индекс локального APT-репозитория.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends dpkg-dev; \
    cd /app/packages; \
    rm -rf partial lock; \
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz; \
    test -s Packages.gz

# --- Этап 2: чистый образ для air-gapped среды ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo

COPY --from=downloader /app/packages/ /opt/local-repo/

# Создаём скрипт офлайн-установки.
RUN <<'EOF'
cat > /opt/local-repo/install-docker-offline.sh <<'SCRIPT'
#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите скрипт через sudo." >&2
    exit 1
fi

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

if [ ! -s "$REPO_DIR/Packages.gz" ]; then
    echo "Ошибка: Packages.gz не найден." >&2
    exit 1
fi

# Проверяем совместимость ОС и архитектуры.
. /etc/os-release
EXPECTED_CODENAME=$(cat "$REPO_DIR/.debian-codename")
EXPECTED_ARCH=$(cat "$REPO_DIR/.architecture")

if [ "${ID:-}" != debian ] || \
   [ "${VERSION_CODENAME:-}" != "$EXPECTED_CODENAME" ]; then
    echo "Требуется Debian $EXPECTED_CODENAME." >&2
    exit 1
fi

if [ "$(dpkg --print-architecture)" != "$EXPECTED_ARCH" ]; then
    echo "Требуется архитектура $EXPECTED_ARCH." >&2
    exit 1
fi

# Временная конфигурация APT.
# Системные репозитории не изменяются.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/sourceparts" "$TMP_DIR/lists/partial"
chmod 755 "$TMP_DIR" "$TMP_DIR/sourceparts" \
    "$TMP_DIR/lists" "$TMP_DIR/lists/partial"

printf 'deb [trusted=yes] file:%s ./\n' "$REPO_DIR" \
    > "$TMP_DIR/sources.list"

apt_local() {
    apt-get \
        -o "Dir::Etc::sourcelist=$TMP_DIR/sources.list" \
        -o "Dir::Etc::sourceparts=$TMP_DIR/sourceparts" \
        -o "Dir::State::lists=$TMP_DIR/lists" \
        -o 'APT::Get::List-Cleanup=0' \
        "$@"
}

echo "Обновляем локальный APT-индекс..."
apt_local update

echo "Устанавливаем Docker, Buildx и Compose..."
apt_local install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "Проверяем версии:"
docker --version
docker buildx version
docker compose version

echo "Установка завершена."
echo "Для запуска демона: systemctl enable --now docker"
SCRIPT

chmod +x /opt/local-repo/install-docker-offline.sh
EOF

CMD ["/bin/sh"]
