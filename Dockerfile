FROM python:3.10-slim

# --- УСТАНАВЛИВАЕМ ЧАСОВОЙ ПОЯС ---
ENV TZ=Europe/Kyiv
RUN apt-get update && apt-get install -y nginx cron git tzdata fcgiwrap && rm -rf /var/lib/apt/lists/*

# Устанавливаем часовой пояс в системе
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# --- ФИКС КОДИРОВКИ СИСТЕМЫ ---
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONIOENCODING=utf-8

WORKDIR /app

RUN git clone https://github.com/Scorpikor/pynod-mirror-tool.git .
RUN pip install --no-cache-dir requests tqdm

RUN mkdir -p /app/mirror/data /app/mirror/eset_upd \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/lib/nginx/body \
    && touch /var/log/nginx/access.log /var/log/nginx/error.log \
    && chmod -R 777 /app /var/log/nginx /var/lib/nginx /etc/nginx

COPY nginx.conf /etc/nginx/sites-available/default
COPY start.sh .

EXPOSE 7860

CMD ["bash", "start.sh"]
