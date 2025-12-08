FROM python:3.12-bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN mkdir -p /app/reports

CMD ["uwsgi", "--socket", "/app/reports/sock_reports.sock", "--chdir", "/app/reports", "--module", "project.wsgi", "--chmod-socket=777", "--uid=root", "--enable-threads", "--buffer-size=65535"]
