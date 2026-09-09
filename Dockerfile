FROM python:3.10-slim

ENV TZ=Europe/Kyiv \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONIOENCODING=utf-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx fcgiwrap git tzdata curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app

RUN git clone --depth 1 https://github.com/Scorpikor/pynod-mirror-tool.git /app/pynod

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

RUN mkdir -p /app/mirror/data /app/mirror/eset_upd \
    /var/log/nginx /var/lib/nginx/body

COPY nginx.conf /etc/nginx/sites-available/default
COPY start.sh /app/start.sh
COPY README.md /app/README.md

RUN chmod +x /app/start.sh \
    && chown -R root:root /app \
    && chmod -R a+rX /app \
    && chmod -R 777 /app/mirror /var/log/nginx /var/lib/nginx

EXPOSE 7860

CMD ["/app/start.sh"]
