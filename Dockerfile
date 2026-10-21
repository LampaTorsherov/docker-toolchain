ARG DEBIAN_VERSION=debian:11
FROM ${DEBIAN_VERSION} AS downloader

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app/packages

# Полностью отключаем все проверки безопасности APT для архивных репозиториев через глобальный конфиг
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::https::Verify-Peer "false";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::https::Verify-Host "false";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99disable-security

# Тотальная очистка старых репозиториев и запись чистых путей archive.debian.org (только по http)
RUN rm -rf /etc/apt/sources.list.d/* && \
    if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "$VERSION_ID" = "10" ] || [ "$VERSION_ID" = "11" ]; then \
            echo "Debian $VERSION_ID detected. Overwriting sources to archive.debian.org..."; \
            echo "deb http://debian.org ${VERSION_CODENAME} main" > /etc/apt/sources.list; \
            if [ "$VERSION_ID" = "10" ]; then \
                echo "deb http://debian.org ${VERSION_CODENAME}/updates main" >> /etc/apt/sources.list; \
            fi; \
            if [ "$VERSION_ID" = "11" ]; then \
                echo "deb http://debian.org ${VERSION_CODENAME}-security main" >> /etc/apt/sources.list; \
                echo "deb http://debian.org ${VERSION_CODENAME}-updates main" >> /etc/apt/sources.list; \
            fi; \
        fi; \
    fi

# Обновляем кэш и устанавливаем утилиты. Ошибки игнорируем через || true, так как архивы могут отдавать предупреждения
RUN apt-get update || true && \
    apt-get install -y --no-install-recommends \
    apt-rdepends \
    dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем git и все его транзитивные зависимости
RUN apt-get update || true && \
    DOWNLOAD_LIST=$(apt-rdepends git | grep -v "^ " | grep -vE "^(debconf|dpkg|libc-bin|base-files|base-passwd|bash|coreutils|dash|diffutils|findutils|grep|gzip|hostname|init-system-helpers|login|ncurses-base|ncurses-bin|perl-base|sed|tar|util-linux|sysvinit-utils|mount)$") && \
    apt-get download ${DOWNLOAD_LIST}

# Создаем индекс локального репозитория
RUN dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# --- Финальный этап: чистый образ для работы без интернета ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo

# Переносим созданный оффлайн-репозиторий
COPY --from=downloader /app/packages /opt/local-repo

# Создаем скрипт автоматической установки для air-gapped контура
RUN echo '#!/bin/sh\n\
echo "Настройка локального репозитория..."\n\
echo "deb [trusted=yes] file:/opt/local-repo ./" > /etc/apt/sources.list.d/local.list\n\
if [ -f /etc/apt/sources.list ]; then mv /etc/apt/sources.list /etc/apt/sources.list.bak; fi\n\
apt-get update\n\
apt-get install -y --no-install-recommends git\n\
if [ -f /etc/apt/sources.list.bak ]; then mv /etc/apt/sources.list.bak /etc/apt/sources.list; fi\n\
rm /etc/apt/sources.list.d/local.list\n\
echo "Git успешно установлен!"' > /usr/local/bin/install-git-offline.sh && \
    chmod +x /usr/local/bin/install-git-offline.sh

CMD ["/bin/bash"]
