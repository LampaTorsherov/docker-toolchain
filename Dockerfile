
# syntax=docker/dockerfile:1.7

# Postgres Pro Standard 15.14.1-1.17x8664 compatibility base.
# amd64 only. No proprietary Postgres Pro packages are used in this build.

# -----------------------------------------------------------------------------
# Debian 10: legacy ABI
# -----------------------------------------------------------------------------
FROM debian/eol:buster-slim AS buster-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    printf 'Acquire::Check-Valid-Until "false";\n' \
        > /etc/apt/apt.conf.d/99archive-no-valid-until; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download \
        'libicu63=63.1-6+deb10u3' \
        'libreadline7=7.0-5'; \
    test "$(find /out -maxdepth 1 -name '*.deb' | wc -l)" -eq 2; \
    dpkg-deb -f /out/libicu63_*.deb Package Version; \
    dpkg-deb -f /out/libreadline7_*.deb Package Version

# -----------------------------------------------------------------------------
# Debian 11: legacy LDAP and OpenSSL
# -----------------------------------------------------------------------------
FROM debian/eol:bullseye-slim AS bullseye-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    printf '%s\n' \
        'deb [check-valid-until=no] http://archive.debian.org/debian bullseye main' \
        'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20260903T220410Z/ bullseye-security main' \
        > /etc/apt/sources.list; \
    rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download \
        'libldap-2.4-2=2.4.57+dfsg-3+deb11u1' \
        'libssl1.1=1.1.1w-0+deb11u8'; \
    test "$(find /out -maxdepth 1 -name '*.deb' | wc -l)" -eq 2; \
    dpkg-deb -f /out/libldap-2.4-2_*.deb Package Version; \
    dpkg-deb -f /out/libssl1.1_*.deb Package Version

# -----------------------------------------------------------------------------
# Debian 13: Zstandard >= 1.5.5
# -----------------------------------------------------------------------------
FROM debian:13-slim AS trixie-libs

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    apt-get update; \
    mkdir -p /out; \
    cd /out; \
    apt-get download 'libzstd1=1.5.7+dfsg-1+deb13u1'; \
    test "$(find /out -maxdepth 1 -name 'libzstd1_*.deb' | wc -l)" -eq 1; \
    dpkg-deb -f /out/libzstd1_*.deb Package Version

# -----------------------------------------------------------------------------
# Final runtime: Debian 12 Bookworm
# -----------------------------------------------------------------------------
FROM debian:12.15-slim

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

COPY --from=buster-libs /out/*.deb /tmp/compat/
COPY --from=bullseye-libs /out/*.deb /tmp/compat/
COPY --from=trixie-libs /out/*.deb /tmp/compat/

RUN set -eux; \
    test "$(dpkg --print-architecture)" = amd64; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod 0755 /usr/sbin/policy-rc.d; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        coreutils \
        debconf \
        gosu \
        grep \
        less \
        locales \
        readline-common \
        sed \
        ssl-cert \
        tzdata \
        libc6 \
        libgcc-s1 \
        libstdc++6 \
        libgnutls30 \
        libgssapi-krb5-2 \
        liblz4-1 \
        libpam0g \
        libsasl2-2 \
        libsystemd0 \
        libtinfo6 \
        libunwind8 \
        libxml2 \
        libxslt1.1 \
        libuuid1 \
        zlib1g \
        libffi8 \
        libssl3 \
        libreadline8 \
        libbz2-1.0 \
        libcrypt1 \
        libexpat1 \
        libgdbm6 \
        libgdbm-compat4 \
        liblzma5 \
        libncursesw6 \
        libsqlite3-0 \
        /tmp/compat/*.deb; \
    apt-get check; \
    dpkg --audit; \
    test "$(dpkg-query -W -f='${Status}' libicu63)" = 'install ok installed'; \
    test "$(dpkg-query -W -f='${Status}' libreadline7)" = 'install ok installed'; \
    test "$(dpkg-query -W -f='${Status}' libldap-2.4-2)" = 'install ok installed'; \
    test "$(dpkg-query -W -f='${Status}' libssl1.1)" = 'install ok installed'; \
    test "$(dpkg-query -W -f='${Status}' libffi8)" = 'install ok installed'; \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libzstd1)" ge '1.5.5'; \
    test -e /usr/lib/x86_64-linux-gnu/libicuuc.so.63; \
    test -e /usr/lib/x86_64-linux-gnu/libreadline.so.7; \
    test -e /usr/lib/x86_64-linux-gnu/libssl.so.1.1; \
    test -e /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1; \
    test -e /usr/lib/x86_64-linux-gnu/libldap-2.4.so.2; \
    test -e /usr/lib/x86_64-linux-gnu/liblber-2.4.so.2; \
    test -e /usr/lib/x86_64-linux-gnu/libzstd.so.1; \
    test -e /usr/lib/x86_64-linux-gnu/libffi.so.8; \
    sed -ri 's/^# (en_US.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    sed -ri 's/^# (ru_RU.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    locale-gen; \
    gosu nobody true; \
    ldconfig; \
    mkdir -p /usr/share/pgpro-base; \
    dpkg-query -W -f='${binary:Package}=${Version}\n' \
        > /usr/share/pgpro-base/packages.lock; \
    sha256sum /tmp/compat/*.deb \
        > /usr/share/pgpro-base/compat-debs.sha256; \
    rm -rf /tmp/compat /var/lib/apt/lists/*

CMD ["bash"]
