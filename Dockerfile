# Для Астры используем официальный образ: registry.astralinux.ru/astra/se17
# Для Debian можно передать --build-arg DEBIAN_VERSION=debian:12
ARG DEBIAN_VERSION=registry.astralinux.ru/astra/se17
FROM ${DEBIAN_VERSION} AS downloader

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app/packages

# Настройка репозиториев: проверяем Астра это или старый Debian
RUN rm -rf /etc/apt/sources.list.d/* && \
    if [ -f /etc/os-release ] && grep -q 'Astra Linux' /etc/os-release; then \
        echo "Astra Linux detected. Setting up Astra 1.7 main repository..."; \
        # Публичное зеркало Astra Linux 1.7 SE
        echo "deb http://astralinux.ru 1.7_x86-64 main contrib non-free" > /etc/apt/sources.list; \
    else \
        . /etc/os-release; \
        echo "Debian/Standard OS detected: $VERSION_CODENAME"; \
        if [ "$VERSION_ID" = "10" ] || [ "$VERSION_ID" = "11" ]; then \
            echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99disable-security && \
            echo "deb http://debian.org ${VERSION_CODENAME} main contrib non-free" > /etc/apt/sources.list; \
        fi; \
    fi

# Вместо капризного apt-rdepends используем встроенный в apt-get механизм разрешения зависимостей
# Скачиваем ТОЛЬКО то, что нужно для git, без установки лишнего мусора в систему
RUN apt-get update && \
    apt-get install -y --download-only --no-install-recommends git && \
    # Переносим все скачанные deb-файлы из кэша apt в нашу рабочую директорию
    cp /var/cache/apt/archives/*.deb /app/packages/

# --- Финальный этап: перенос пакетов в чистый образ для Air-Gap ---
FROM ${DEBIAN_VERSION}

WORKDIR /opt/local-repo
COPY --from=downloader /app/packages /opt/local-repo

# Оффлайн-скрипт установки "все в одном" через dpkg -R
RUN echo '#!/bin/sh\n\
echo "Запуск автономной установки Git..."\n\
dpkg -R -i /opt/local-repo/\n\
echo "Готово! Проверяем версию:"\n\
git --version' > /usr/local/bin/install-git-offline.sh && \
    chmod +x /usr/local/bin/install-git-offline.sh

CMD ["/bin/bash"]
