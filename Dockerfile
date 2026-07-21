# syntax=docker/dockerfile:1.7

#
# Получаем старые ABI-библиотеки через APT из соответствующих выпусков Debian.
#

FROM debian/eol:buster-slim AS buster-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    printf 'Acquire::Check-Valid-Until "false";\n' \
        > /etc/apt/apt.conf.d/99archive-no-valid-until; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download \
        libicu63 \
        libreadline7; \
    ls -lh /out/*.deb


FROM debian:11-slim AS bullseye-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download \
        libldap-2.4-2 \
        libssl1.1; \
    ls -lh /out/*.deb


FROM debian:13-slim AS trixie-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download \
        libzstd1; \
    ls -lh /out/*.deb


#
# Итоговая база — Debian 12.
#

FROM debian:12-slim

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

COPY --from=buster-libs /out/*.deb /tmp/legacy-debs/
COPY --from=bullseye-libs /out/*.deb /tmp/legacy-debs/
COPY --from=trixie-libs /out/*.deb /tmp/legacy-debs/

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod 0755 /usr/sbin/policy-rc.d; \
    \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        gosu \
        ca-certificates \
        coreutils \
        debconf \
        grep \
        libc6 \
        libgcc-s1 \
        libgnutls30 \
        libgssapi-krb5-2 \
        liblz4-1 \
        libpam0g \
        libsasl2-2 \
        libstdc++6 \
        libsystemd0 \
        libtinfo6 \
        libunwind8 \
        libxml2 \
        locales \
        readline-common \
        sed \
        ssl-cert \
        tzdata \
        zlib1g \
        libxml2 \
        libxslt1.1 \
        libsasl2-2 \
        /tmp/legacy-debs/*.deb; \
    \
    apt-get check; \
    dpkg --audit; \
    ldconfig; \
    \
    zstd_version="$(dpkg-query -W -f='${Version}' libzstd1)"; \
    dpkg --compare-versions "$zstd_version" ge "1.5.5"; \
    \
    test -e /usr/lib/x86_64-linux-gnu/libicuuc.so.63; \
    test -e /usr/lib/x86_64-linux-gnu/libreadline.so.7; \
    test -e /usr/lib/x86_64-linux-gnu/libssl.so.1.1; \
    test -e /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1; \
    test -e /usr/lib/x86_64-linux-gnu/libldap-2.4.so.2; \
    test -e /usr/lib/x86_64-linux-gnu/liblber-2.4.so.2; \
    test -e /usr/lib/x86_64-linux-gnu/libzstd.so.1; \
    \
    sed -ri 's/^# (en_US.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    sed -ri 's/^# (ru_RU.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    locale-gen; \
    \
    echo 'Installed runtime packages:'; \
    dpkg-query -W -f='${Package}=${Version}\n' \
        libc6 \
        libicu63 \
        liblz4-1 \
        libreadline7 \
        libssl1.1 \
        libzstd1 \
        zlib1g \
        libgssapi-krb5-2 \
        libldap-2.4-2 \
        libpam0g \
        libsystemd0 \
        libunwind8 \
        libxml2 \
        coreutils \
        grep \
        sed \
        tzdata \
        ssl-cert \
        locales; \
    \
    rm -rf /tmp/legacy-debs; \
    rm -rf /var/lib/apt/lists/*

CMD ["bash"]
