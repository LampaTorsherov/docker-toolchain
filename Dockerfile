FROM python:3.12-alpine

RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    postgresql-dev \
    linux-headers 

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/reports

CMD ["uwsgi", "--socket", "/app/reports/sock_reports.sock", "--chdir", "/app/reports", "--module", "project.wsgi", "--chmod-socket=777", "--uid=root", "--enable-threads", "--buffer-size=65535"]
