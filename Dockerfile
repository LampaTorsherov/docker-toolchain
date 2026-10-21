# По умолчанию используем debian:11, но можно передать любую версию через --build-arg
ARG DEBIAN_VERSION=debian:11
FROM ${DEBIAN_VERSION} AS downloader

# Отключаем интерактивные диалоги apt
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app/packages

# Динамическая настройка репозиториев в зависимости от версии Debian
RUN if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "$VERSION_ID" = "10" ] || [ "$VERSION_ID" = "11" ]; then \
            echo "Debian $VERSION_ID detected. Switching sources to archive.debian.org..."; \
            # Полностью заменяем источники на архивные
            echo "deb http://debian.org ${VERSION_CODENAME} main" > /etc/apt/sources.list; \
            echo "deb http://debian.org ${VERSION_CODENAME}-security main" >> /etc/apt/sources.list; \
            # Опционально добавляем updates, если они нужны (для Debian 10 buster-updates не всегда доступен в архиве)
            if [ "$VERSION_ID" = "11" ]; then \
                echo "deb http://debian.org ${VERSION_CODENAME}-updates main" >> /etc/apt/sources.list; \
            fi; \
        fi; \
    fi

# Настраиваем apt на игнорирование старых меток валидности (для архивных репозиториев)
# и обновляем кэш, устанавливая необходимые утилиты
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    apt-rdepends \
    dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем git и все его транзитивные зависимости
RUN apt-get update && \
    DOWNLOAD_LIST=$(apt-rdepends git | grep -v "^ " | grep -vE "^(debconf|dpkg|libc-bin|base-files|base-passwd|bash|coreutils|dash|diffutils|findutils|grep|gzip|hostname|init-system-helpers|login|ncurses-base|ncurses-bin|perl-base|sed|tar|util-linux|sysvinit-utils|mount)$") && \
    apt-get download ${DOWNLOAD_LIST}

# Создаем индекс локального репозитория (Packages.gz)
RUN dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# --- Финальный этап: чистый образ для работы без интернета ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo

# Переносим скачанный кэш пакетов
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
