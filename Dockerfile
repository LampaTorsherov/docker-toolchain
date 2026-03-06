FROM debian:12 AS builder

# Аргументы сборки
ARG ASTERISK_VERSION=22
ARG ASTERISK_SOURCE=asterisk-22-current.tar.gz

# Установка зависимостей для сборки
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    subversion \
    libedit-dev \
    libjansson-dev \
    libsqlite3-dev \
    uuid-dev \
    libxml2-dev \
    libxslt1-dev \
    libssl-dev \
    libsrtp2-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    libiodbc2-dev \
    libneon27-dev \
    libgmime-3.0-dev \
    liblua5.2-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libogg-dev \
    libvorbis-dev \
    libopus-dev \
    libspandsp-dev \
    libresample1-dev \
    libldap2-dev \
    libmariadb-dev \
    python3-dev \
    python3-pip \
    unixodbc-dev \
    libtool \
    pkg-config \
    autoconf \
    automake \
    libmp3lame-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/asterisk

# Копирование исходников
COPY ${ASTERISK_SOURCE} .

# Распаковка исходников
RUN tar xzf ${ASTERISK_SOURCE} --strip-components=1

# Конфигурация
RUN ./configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-jansson-bundled=no \
    --with-pjproject-bundled=yes \
    --with-crypto \
    --with-ssl \
    --with-srtp \
    --with-speex \
    --with-speexdsp \
    --with-opus \
    --with-ogg \
    --with-vorbis \
    --with-mp3lame \
    --with-spandsp \
    --with-resample \
    --with-curl \
    --with-postgresql \
    --with-iodbc \
    --with-lua \
    --with-neon \
    --with-gmime \
    --with-ldap \
    --with-sqlite3

# Выбор модулей с отключенным BUILD_NATIVE
RUN make menuselect.makeopts && \
    menuselect/menuselect \
    --disable BUILD_NATIVE \
    --enable format_mp3 \
    --enable format_wav \
    --enable format_ogg_vorbis \
    --enable codec_opus \
    --enable codec_silk \
    --enable codec_siren7 \
    --enable codec_siren14 \
    --enable codec_g722 \
    --enable codec_g726 \
    --enable codec_lpc10 \
    --enable codec_adpcm \
    --enable codec_alaw \
    --enable codec_ulaw \
    --enable codec_speex \
    --enable res_pjsip \
    --enable res_pjsip_websocket \
    --enable res_pjsip_exten_state \
    --enable res_pjsip_log_forwarder \
    --enable res_pjsip_mwi \
    --enable res_pjsip_outbound_authenticator_digest \
    --enable res_pjsip_outbound_publish \
    --enable res_pjsip_pubsub \
    --enable res_pjsip_refer \
    --enable res_pjsip_registrar \
    --enable res_pjsip_rfc3326 \
    --enable res_pjsip_sdp_rtp \
    --enable res_pjsip_send_to_voicemail \
    --enable res_pjsip_session \
    --enable res_pjsip_t38 \
    --enable res_http_websocket \
    --enable res_srtp \
    --enable res_crypto \
    --enable res_curl \
    --enable res_odbc \
    --enable res_config_odbc \
    --enable res_config_ldap \
    --enable func_odbc \
    --enable func_curl \
    --enable cdr_odbc \
    --enable cdr_pgsql \
    --enable res_sqlite \
    --enable app_dial \
    --enable app_playback \
    --enable app_queue \
    --enable chan_pjsip \
    menuselect.makeopts

# Компиляция и установка
RUN make -j$(nproc)
RUN make install
RUN make config
RUN make install-logrotate

# Финальный образ
FROM debian:12

# Установка рантайм зависимостей
RUN apt-get update && apt-get install -y \
    libedit2 \
    libjansson4 \
    libsqlite3-0 \
    libxml2 \
    libxslt1.1 \
    libssl3 \
    libsrtp2-1 \
    libcurl4 \
    libpq5 \
    libiodbc2 \
    libneon27-gnutls \
    libgmime-3.0-0 \
    liblua5.2-0 \
    libspeex1 \
    libspeexdsp1 \
    libogg0 \
    libvorbis0a \
    libvorbisfile3 \
    libopus0 \
    libspandsp2 \
    libresample1 \
    libldap-2.5-0 \
    libmariadb3 \
    python3 \
    unixodbc \
    libmp3lame0 \
    netcat-openbsd \
    procps \
    sqlite3 \
    odbc-postgresql \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Копирование собранного Asterisk из builder
COPY --from=builder /usr/sbin/asterisk /usr/sbin/
COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
COPY --from=builder /usr/lib/x86_64-linux-gnu/asterisk /usr/lib/x86_64-linux-gnu/asterisk
COPY --from=builder /etc/asterisk /etc/asterisk
COPY --from=builder /var/lib/asterisk /var/lib/asterisk
COPY --from=builder /var/spool/asterisk /var/spool/asterisk
COPY --from=builder /var/log/asterisk /var/log/asterisk
COPY --from=builder /usr/share/asterisk /usr/share/asterisk

# Создание пользователя asterisk
RUN groupadd -r asterisk && useradd -r -g asterisk -d /var/lib/asterisk -s /bin/false asterisk && \
    chown -R asterisk:asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /etc/asterisk

# Создание директорий для volume'ов
RUN mkdir -p /etc/asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /var/run/asterisk && \
    chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /var/run/asterisk

USER asterisk
CMD ["asterisk", "-f"]
