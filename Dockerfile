ARG DEBIAN_VERSION=debian:11
FROM ${DEBIAN_VERSION} AS downloader

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app/packages

# Настраиваем конфигурацию APT на полное игнорирование проверок подписей и дат (для archive.debian.org)
RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'Binary::apt::APT::Options:: "--allow-insecure-repositories";' >> /etc/apt/apt.conf.d/99no-check-valid-until

# Динамически переписываем sources.list под архивы (исправлены пути для debian-security)
RUN if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "$VERSION_ID" = "10" ] || [ "$VERSION_ID" = "11" ]; then \
            echo "Debian $VERSION_ID detected. Switching sources to archive.debian.org..."; \
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

# Запускаем обновление с флагами игнорирования ключей и устанавливаем утилиты
RUN apt-get update --allow-insecure-repositories || true && \
    apt-get install -y --no-install-recommends \
    --allow-unauthenticated \
    --allow-insecure-repositories \
    apt-rdepends \
    dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем git и транзитивные зависимости (добавлены флаги игнорирования для apt-get download)
RUN apt-get update --allow-insecure-repositories || true && \
    DOWNLOAD_LIST=$(apt-rdepends git | grep -v "^ " | grep -vE "^(debconf|dpkg|libc-bin|base-files|base-passwd|bash|coreutils|dash|diffutils|findutils|grep|gzip|hostname|init-system-helpers|login|ncurses-base|ncurses-bin|perl-base|sed|tar|util-linux|sysvinit-utils|mount)$") && \
    apt-get download -o APT::Get::AllowUnauthenticated=true ${DOWNLOAD_LIST}

# Формируем индекс локального репозитория
RUN dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# --- Финальный этап: чистый образ для работы без интернета ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo

COPY --from=downloader /app/packages /opt/local-repo

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
