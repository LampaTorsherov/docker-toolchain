# syntax=docker/dockerfile:1.7

# Postgres Pro packages are amd64 in this scenario.
# Build with --platform=linux/amd64.

ARG ZSTD_VERSION=1.5.5

FROM debian/eol:buster-slim AS zstd-builder
ARG ZSTD_VERSION

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    printf 'Acquire::Check-Valid-Until "false";\n' \
        > /etc/apt/apt.conf.d/99archive-no-valid-until; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        dpkg-dev; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl --fail --location --retry 5 \
        "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" \
        --output /tmp/zstd.tar.gz; \
    mkdir -p /tmp/zstd-src; \
    tar -xzf /tmp/zstd.tar.gz \
        --strip-components=1 \
        --directory=/tmp/zstd-src; \
    make -C /tmp/zstd-src/lib -j"$(nproc)"; \
    arch="$(dpkg --print-architecture)"; \
    multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"; \
    pkgroot="/tmp/libzstd1"; \
    install -d \
        "$pkgroot/DEBIAN" \
        "$pkgroot/usr/lib/$multiarch" \
        "$pkgroot/usr/share/doc/libzstd1"; \
    install -m 0755 \
        "/tmp/zstd-src/lib/libzstd.so.${ZSTD_VERSION}" \
        "$pkgroot/usr/lib/$multiarch/libzstd.so.${ZSTD_VERSION}"; \
    ln -s "libzstd.so.${ZSTD_VERSION}" \
        "$pkgroot/usr/lib/$multiarch/libzstd.so.1"; \
    printf '%s\n' \
        "Package: libzstd1" \
        "Version: ${ZSTD_VERSION}-1local" \
        "Section: libs" \
        "Priority: optional" \
        "Architecture: ${arch}" \
        "Maintainer: Local offline image build" \
        "Depends: libc6 (>= 2.17)" \
        "Description: Zstandard runtime library ${ZSTD_VERSION}" \
        " Locally packaged for the offline Postgres Pro runtime image." \
        > "$pkgroot/DEBIAN/control"; \
    printf '#!/bin/sh\nset -e\nldconfig\n' \
        > "$pkgroot/DEBIAN/postinst"; \
    printf '#!/bin/sh\nset -e\nldconfig\n' \
        > "$pkgroot/DEBIAN/postrm"; \
    chmod 0755 \
        "$pkgroot/DEBIAN/postinst" \
        "$pkgroot/DEBIAN/postrm"; \
    printf 'Built from upstream zstd %s\n' "$ZSTD_VERSION" \
        > "$pkgroot/usr/share/doc/libzstd1/BUILD-INFO"; \
    mkdir -p /out; \
    dpkg-deb --build "$pkgroot" \
        "/out/libzstd1_${ZSTD_VERSION}-1local_${arch}.deb"; \
    dpkg-deb --info /out/libzstd1_*.deb

FROM debian/eol:buster-slim

ARG ZSTD_VERSION=1.5.5

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

COPY --from=zstd-builder /out/libzstd1_*.deb /tmp/

RUN set -eux; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod 0755 /usr/sbin/policy-rc.d; \
    printf 'Acquire::Check-Valid-Until "false";\n' \
        > /etc/apt/apt.conf.d/99archive-no-valid-until; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        coreutils \
        grep \
        libc6 \
        libgssapi-krb5-2 \
        libicu63 \
        libldap-2.4-2 \
        liblz4-1 \
        libpam0g \
        libreadline7 \
        libssl1.1 \
        libsystemd0 \
        libunwind8 \
        libxml2 \
        locales \
        sed \
        ssl-cert \
        tzdata \
        zlib1g; \
        libxml2 \
        libxslt1.1 \
        locales \
    dpkg -i /tmp/libzstd1_*.deb; \
    apt-get check; \
    dpkg --audit; \
    installed_zstd="$(dpkg-query -W -f='${Version}' libzstd1)"; \
    dpkg --compare-versions "$installed_zstd" ge "$ZSTD_VERSION"; \
    sed -ri 's/^# (en_US.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    sed -ri 's/^# (ru_RU.UTF-8 UTF-8)$/\1/' /etc/locale.gen; \
    locale-gen; \
    ldconfig; \
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
    rm -f /tmp/libzstd1_*.deb; \
    rm -rf /var/lib/apt/lists/*

CMD ["bash"]
