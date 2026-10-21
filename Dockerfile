ARG DEBIAN_VERSION=debian:11
FROM ${DEBIAN_VERSION} AS downloader

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app/packages

RUN echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99disable-security && \
    echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99disable-security

RUN rm -rf /etc/apt/sources.list.d/* && \
    if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "$VERSION_ID" = "10" ] || [ "$VERSION_ID" = "11" ]; then \
            echo "deb http://debian.org ${VERSION_CODENAME} main" > /etc/apt/sources.list; \
            if [ "$VERSION_ID" = "10" ]; then echo "deb http://debian.org ${VERSION_CODENAME}/updates main" >> /etc/apt/sources.list; fi; \
            if [ "$VERSION_ID" = "11" ]; then echo "deb http://debian.org ${VERSION_CODENAME}-security main" >> /etc/apt/sources.list; fi; \
        fi; \
    fi

# Нам нужен ТОЛЬКО apt-rdepends, чтобы построить список транзитивных зависимостей
RUN apt-get update || true && \
    apt-get install -y --no-install-recommends apt-rdepends && \
    rm -rf /var/lib/apt/lists/*

# Скачиваем git и транзитивки
RUN apt-get update || true && \
    DOWNLOAD_LIST=$(apt-rdepends git | grep -v "^ " | grep -vE "^(debconf|dpkg|libc-bin|base-files|base-passwd|bash|coreutils|dash|diffutils|findutils|grep|gzip|hostname|init-system-helpers|login|ncurses-base|ncurses-bin|perl-base|sed|tar|util-linux|sysvinit-utils|mount)$") && \
    apt-get download ${DOWNLOAD_LIST}

# --- Финальный этап ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo
COPY --from=downloader /app/packages /opt/local-repo

# Скрипт ставит всё напрямую через dpkg, скармливая ему всю папку.
# dpkg сам разберется с порядком установки, если использовать ключ -R (recursive)
RUN echo '#!/bin/sh\n\
echo "Установка Git из локальных пакетов..."\n\
dpkg -R -i /opt/local-repo/\n\
echo "Git успешно установлен!"' > /usr/local/bin/install-git-offline.sh && \
    chmod +x /usr/local/bin/install-git-offline.sh

CMD ["/bin/bash"]
