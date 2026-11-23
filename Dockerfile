
FROM python:3.11.18-slim-bookworm AS build

ARG PATRONI_VERSION=4.1.5

RUN mkdir -p /patroni \
    && cp -a /usr/local/. /patroni/

ENV PYTHONHOME=/patroni \
    LD_LIBRARY_PATH=/patroni/lib \
    PATH=/patroni/bin:${PATH} \
    PYTHONUNBUFFERED=1

RUN python3 -m pip install \
      --no-cache-dir \
      "patroni[etcd,etcd3,psycopg3]==${PATRONI_VERSION}" \
    && python3 -m pip check \
    && python3 -c "import sys; assert sys.prefix == '/patroni'" \
    && python3 -c "import patroni.dcs.etcd, patroni.dcs.etcd3, psycopg, ctypes, ssl" \
    && patroni --version

FROM scratch

COPY --from=build /patroni /patroni
