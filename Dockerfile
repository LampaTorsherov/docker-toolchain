
# syntax=docker/dockerfile:1.7

# Единственное исключение из Bookworm:
# Postgres Pro требует libzstd1 >= 1.5.5.

FROM --platform=linux/amd64 debian:13-slim AS zstd

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download 'libzstd1=1.5.7+dfsg-1'; \
    test "$(find /out -maxdepth 1 -name 'libzstd1_*.deb' | wc -l)" -eq 1

# Последний Debian 12 Bookworm.

FROM --platform=linux/amd64 debian:12.15-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY --from=zstd /out/libzstd1_*.deb /tmp/zstd/

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod 0755 /usr/sbin/policy-rc.d; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        'ca-certificates=20250419~deb12u2' \
        'gosu=1.14-1+b10' \
        'libffi8=3.4.4-1' \
        'libicu72=72.1-3+deb12u1' \
        'libreadline8=8.2-1.3' \
        'libssl3=3.0.22-1~deb12u2' \
        'libldap-2.5-0=2.5.13+dfsg-5' \
        'liblz4-1=1.9.4-1' \
        'libgcc-s1=12.2.0-14+deb12u1' \
        'libstdc++6=12.2.0-14+deb12u1' \
        'libxml2=2.9.14+dfsg-1.3~deb12u6' \
        'libxslt1.1=1.1.35-1+deb12u4' \
        'libgnutls30=3.7.9-2+deb12u7' \
        'libgssapi-krb5-2=1.20.1-2+deb12u5' \
        'libsasl2-2=2.1.28+dfsg-10+deb12u1' \
        'libpam0g=1.5.2-6+deb12u2' \
        'libsystemd0=252.39-1~deb12u2' \
        'libunwind8=1.6.2-3' \
        'libtinfo6=6.4-4' \
        'zlib1g=1:1.2.13.dfsg-1' \
        'locales=2.36-9+deb12u14' \
        'tzdata' \
        'ssl-cert=1.1.2' \
        /tmp/zstd/*.deb; \
    \
    dpkg --compare-versions \
        "$(dpkg-query -W -f='${Version}' libzstd1)" \
        ge 1.5.5; \
    test "$(dpkg-query -W -f='${Version}' libzstd1)" = '1.5.7+dfsg-1'; \
    \
    printf 'en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8\n' \
        > /etc/locale.gen; \
    locale-gen; \
    \
    gosu nobody true; \
    apt-get check; \
    dpkg --audit; \
    ldconfig; \
    \
    mkdir -p /usr/share/pgpro-base; \
    dpkg-query -W -f='${binary:Package}=${Version}\n' \
        > /usr/share/pgpro-base/packages.lock; \
    \
    rm -rf /tmp/zstd /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

CMD ["bash"]
