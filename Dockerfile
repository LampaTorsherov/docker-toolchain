# Имя базового образа передается через --build-arg (например, debian:11)
ARG DEBIAN_VERSION=debian:12
FROM ${DEBIAN_VERSION} AS downloader

# Отключаем интерактивные диалоги apt
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app/packages

# Обновляем кэш и устанавливаем apt-rdepends для поиска транзитивных зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-rdepends \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем git и ВСЕ его транзитивные зависимости (исключая уже предустановленные core-пакеты)
RUN apt-get update && \
    DOWNLOAD_LIST=$(apt-rdepends git | grep -v "^ " | grep -vE "^(debconf|dpkg|libc-bin|base-files|base-passwd|bash|coreutils|dash|diffutils|findutils|grep|gzip|hostname|init-system-helpers|login|ncurses-base|ncurses-bin|perl-base|sed|tar|util-linux|sysvinit-utils|mount)$") && \
    apt-get download ${DOWNLOAD_LIST}

# Создаем локальный индекс пакетов (чтобы apt внутри air-gap мог разрешать зависимости)
RUN apt-get install -y --no-install-recommends dpkg-dev && \
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

# --- Финальный этап: собираем чистый образ для air-gapped среды ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo

# Копируем скачанные пакеты и индекс из предыдущего этапа
COPY --from=downloader /app/packages /opt/local-repo

# Скрипт-памятка для пользователя, как установить git внутри контейнера без интернета
RUN echo '#!/bin/sh\n\
echo "Настройка локального репозитория..."\n\
echo "deb [trusted=yes] file:/opt/local-repo ./" > /etc/apt/sources.list.d/local.list\n\
mv /etc/apt/sources.list /etc/apt/sources.list.bak\n\
apt-get update\n\
apt-get install -y --no-install-recommends git\n\
mv /etc/apt/sources.list.bak /etc/apt/sources.list\n\
rm /etc/apt/sources.list.d/local.list\n\
echo "Git успешно установлен!"' > /usr/local/bin/install-git-offline.sh && \
    chmod +x /usr/local/bin/install-git-offline.sh

CMD ["/bin/bash"]
