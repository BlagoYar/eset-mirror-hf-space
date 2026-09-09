Создание:

Регистрируемся

[Переходим на создание Space](https://huggingface.co/login?next=%2Fnew-space)

или

**New Space -> Docker -> Blank (остальное индивидуально) -> после перехода в Space жмёте Files** и добавляете файлы ниже через **Contribute - Create a new File** либо **Upload files**
!!! СОБЛЮДАЙТЕ РЕГИСТР БУКВ В НАЗВАНИИ ФАЙЛОВ - ЭТО ВАЖНО !!!


- Чтобы не светить IP нужно добавить в настройках переменную
  **Space -> Settings -> Variables -> ESET_SERVER_URL = YourIP/YourDomain**
- По той же схеме, если нужно имя юзера и парол ESET_SERVER_USER и ESET_SERVER_PASS. Запароленый сервер не проверял, возможно нужно будет подкорректировать.
- Путь к логам в браузере - https://yourdomen.com/synclog
  Потому что в HuggingFace там глюковато с логом "общаться".
  Чтобы не хламилось, сделал только 6 (общих и авто, и ручных) последних логов на вэб-странице Auto Update и Manual.
- Обновление вручную (триггер) - https://yourdomen.com/sync
- Автообновление каждые 6 часов. При ручном обновлении периодичность меняется относительно его.
- Часовой пояс для логов +2 (Europe/Kyiv)
- В логах отметил где авто, а где ручное обновление
- Выделение общего прогресса строками из '='

<details>
  <summary>Пример</summary>

#### Было
```
[ep12] [0] nodC4B21E6D.dll.nup:   0%|          | 0.00/834k [00:00<?, ?B/s]



[ep12] [0] nod1DE92F42.dll.nup:   0%|          | 0.00/62.4k [00:00<?, ?B/s]



                                                                           
[ep12] Общий прогресс:  13%|#3        | 158/1206 [00:15<01:14, 14.12file/s]
[ep12] [0] nod1DA06D7C.dll.nup:   0%|          | 280k/93.5M [00:00<00:59, 1.66MB/s]

[ep12] [0] nod267E5034.dll.nup:   6%|5         | 697k/12.0M [00:00<00:02, 4.25MB/s]


[ep12] [0] nodC4B21E6D.dll.nup:  75%|#######4  | 625k/834k [00:00<00:00, 3.77MB/s]
```

#### Стало
```
[ep12] [0] nod702B853E.dll.nup:  19%|#9        | 504k/2.54M [00:00<00:02, 780kB/s]
[ep12] [0] nodB1512AF8.dll.nup:  39%|###9      | 220k/558k [00:00<00:00, 363kB/s]
[ep12] [0] nod009669AC.dll.nup:   7%|7         | 105k/1.37M [00:00<00:02, 639kB/s]
[ep12] [0] nod00874FC2.dll.nup:  31%|###1      | 495k/1.54M [00:00<00:01, 749kB/s]
[ep12] [0] nod702B853E.dll.nup:  38%|###7      | 984k/2.54M [00:01<00:01, 1.50MB/s]
[ep12] [0] nodB1512AF8.dll.nup:  81%|########  | 450k/558k [00:00<00:00, 739kB/s]

==================================================
= [ep12] Общий прогресс:   0%|          | 5/1206 [00:01<06:22,  3.14file/s] =
==================================================
[ep12] [0] nod009669AC.dll.nup:  23%|##2       | 316k/1.37M [00:00<00:01, 1.02MB/s]
[ep12] [0] nod00874FC2.dll.nup:  62%|######1   | 976k/1.54M [00:01<00:00, 1.45MB/s]
[ep12] [0] nod702B853E.dll.nup:  75%|#######4  | 1.90M/2.54M [00:01<00:00, 2.92MB/s]
[ep12] [0] nod00F6F91A.dll.nup:   0%|          | 0.00/1.13M [00:00<?, ?B/s]
[ep12] [0] nod009669AC.dll.nup:  53%|#####2    | 737k/1.37M [00:00<00:00, 1.71MB/s]

==================================================
= [ep12] Общий прогресс:   1%|          | 7/1206 [00:01<04:07,  4.84file/s] =
==================================================
[ep12] [0] nod0114F278.dll.nup:   0%|          | 0.00/52.2M [00:00<?, ?B/s]
[ep12] [0] nod702B853E.dll.nup:  89%|########9 | 2.26M/2.54M [00:01<00:00, 2.69MB/s]
[ep12] [0] nod00F6F91A.dll.nup:  49%|####9     | 570k/1.13M [00:00<00:00, 3.50MB/s]
```

</details>

<details>
  <summary>Файлы для Space (для ESET v13; если нужна другая, указать в start.sh --> раздел [ESET])</summary>

### Dockerfile
========================================================
```dockerfile
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
```

### nginx.conf
========================================================
```nginx
map $http_user_agent $ver {
    "~^.*(EEA|EES|EFSW|EMSX|ESFW)+\s+Update.*BPC\s+(\d+)\..*$" "ep$2";
    "~^.*Update.*BPC\s+(\d+)\..*$" "v$1";
    default "ep12";
}

server {
    listen 7860 default_server;
    server_name _;
    root /app/mirror;
    index index.html;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive";

    # --- ИСПРАВЛЕНИЕ КОДИРОВКИ ТУТ ---
    location ~* \.(log|txt)$ {
        # ЯВНО УКАЗЫВАЕМ CHARSET=UTF-8
        add_header Content-Type "text/plain; charset=utf-8";
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        expires off;
    }
    
    location /sync {
        proxy_pass http://127.0.0.1:9999;
        add_header Cache-Control "no-store";
    
        # Отдавать лог без расширения
        alias /app/mirror/sync.log;
    }
    location /synclog {
        default_type text/plain;
        add_header Content-Type "text/plain; charset=utf-8";
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        alias /app/mirror/sync.log;
    }
    
    location ~* \.ver$ {
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
        if ($ver ~ "^ep[6-9]$") { rewrite ^/(dll/)?update.ver$ /eset_upd/$ver/$1update.ver break; }
        if ($ver ~ "^ep1[0-9]$") { rewrite ^/(dll/)?update.ver$ /eset_upd/$ver/$1update.ver break; }
        if ($ver ~ "^v[3-8]$") { rewrite ^(.*) /eset_upd/v3/dll/update.ver break; }
        if ($ver ~ "^v1[0-1]$") { rewrite ^(.*) /eset_upd/v10/dll/update.ver break; }
        if ($ver ~ "^v1[2-9]$") { rewrite ^(.*) /eset_upd/$ver/dll/update.ver break; }
        try_files /eset_upd/$ver/dll/update.ver =404;
    }

    location / {
        set $ver_path $ver;
        if ($ver ~ "^v[3-8]$") { set $ver_path v3; }
        if ($ver ~ "^v1[0-1]$") { set $ver_path v10; }
        try_files /data/$ver_path$uri /data/$ver_path/$uri =404;
    }
}
```

### start.sh
```bash
#!/bin/bash

# ============================================================
# НАСТРОЙКИ ОКРУЖЕНИЯ
# ============================================================
export TZ=Europe/Kyiv
export PYTHONIOENCODING=utf-8
export LANG=C.UTF-8

# ============================================================
# НАСТРОЙКА ЛОГОВ И NGINX
# ============================================================
touch /app/mirror/sync.log
chmod 666 /app/mirror/sync.log
ln -sf /var/log/nginx/access.log /app/mirror/access.txt
chmod 666 /var/log/nginx/access.log

echo "Starting Nginx..."
service nginx start

echo "Starting fcgiwrap..."
service fcgiwrap start

# ============================================================
# ФОНОВАЯ РОТАЦИЯ ЛОГОВ NGINX (ОСТАВЛЯЕМ 3 ДНЯ)
# ============================================================
rotate_nginx_logs() {
    LOG_DIR="/var/log/nginx"
    while true; do
        sleep 86400 # Спим 24 часа

        DATE=$(date +%Y-%m-%d)
        
        # Переименовываем текущие файлы
        [ -f "$LOG_DIR/access.log" ] && mv "$LOG_DIR/access.log" "$LOG_DIR/access.log.$DATE"
        [ -f "$LOG_DIR/error.log" ] && mv "$LOG_DIR/error.log" "$LOG_DIR/error.log.$DATE"

        # Даем команду Nginx переоткрыть дескрипторы логов
        nginx -s reopen

        # Удаляем всё, что старше 3 дней
        find "$LOG_DIR" -type f -name "*.log.*" -mtime +3 -exec rm -f {} \;
    done
}
# Запускаем в фоне!
rotate_nginx_logs &

# ============================================================
# WEBHOOK
# ============================================================
cat <<EOF > /app/webhook.py
from http.server import HTTPServer, BaseHTTPRequestHandler
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with open("/app/mirror/manual_trigger", "w") as f: f.write("1")
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b"MANUAL UPDATE STARTED. Check sync.log")
HTTPServer(('127.0.0.1', 9999), Handler).serve_forever()
EOF
python3 /app/webhook.py &

# ============================================================
# СКРИПТ ОЧИСТКИ ЛОГОВ (6 ЛЮБЫХ ПОСЛЕДНИХ ЗАПУСКОВ)
# ============================================================
cat << 'EOF' > /app/filter_logs.py
import re
import sys
import os

log_path = '/app/mirror/sync.log'

if not os.path.exists(log_path):
    sys.exit(0)

with open(log_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Разделяем лог по стартовому маркеру
parts = re.split(r'(=== PREPARING UPDATE \[.*?===)', content)

# Собираем блоки
blocks = []
for i in range(1, len(parts), 2):
    header = parts[i]
    body = parts[i+1] if i+1 < len(parts) else ""
    blocks.append(header + body)

# Оставляем только 6 самых свежих блоков с конца
keep_blocks = blocks[-6:]

# Собираем лог обратно (шапка + оставшиеся блоки)
filtered_log = parts[0] + "".join(keep_blocks)

with open(log_path, 'w', encoding='utf-8') as f:
    f.write(filtered_log)
EOF

# ============================================================
# ПОИСК СКРИПТА
# ============================================================
SCRIPT_PATH=$(find /app -name "update.py" -print -quit)
if [ -z "$SCRIPT_PATH" ]; then
    echo "CRITICAL: update.py not found!" >> /app/mirror/sync.log
    sleep 21600
    exit 1
fi
WORK_DIR=$(dirname "$SCRIPT_PATH")
cd "$WORK_DIR"

# ============================================================
# ФУНКЦИЯ ВРЕМЕНИ
# ============================================================
get_datetime() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# Подчищаем хвосты при рестарте
rm -f /app/mirror/manual_trigger

# ============================================================
# ОСНОВНОЙ ЦИКЛ
# ============================================================
RUN_MODE="AUTO"

while true; do

    echo "=== PREPARING UPDATE [$RUN_MODE] $(get_datetime) ===" >> /app/mirror/sync.log

    # --------------------------------------------------------
    # ОЧИСТКА ПЕРЕМЕННЫХ
    # --------------------------------------------------------
    CLEAN_URL=$(echo "$ESET_SERVER_URL" | xargs)
    CLEAN_RESERVE=$(echo "$ESET_SERVER_URL_RESERVE" | xargs)

    # --------------------------------------------------------
    # ПРОВЕРКА HTTP КОДА
    # --------------------------------------------------------
    echo "[CHECK] Testing connection to: ESET_SERVER_URL" >> /app/mirror/sync.log
    
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" -m 10 -L "$CLEAN_URL" || echo "000")
    if [ -z "$HTTP_CODE" ]; then HTTP_CODE="000"; fi
    
    echo "[CHECK] Response Code: $HTTP_CODE" >> /app/mirror/sync.log
    
    if [ "$HTTP_CODE" != "000" ]; then
        echo "[CHECK] Primary is ONLINE." >> /app/mirror/sync.log
        FINAL_MIRROR="$CLEAN_URL"
        LOG_NAME="ESET_SERVER_URL"
    else
        echo "[CHECK] Primary DOWN (Code 000). Switching to ESET_SERVER_URL_RESERVE..." >> /app/mirror/sync.log
        if [ -z "$CLEAN_RESERVE" ]; then
            echo "[WARNING] Reserve empty! Forced Primary." >> /app/mirror/sync.log
            FINAL_MIRROR="$CLEAN_URL"
            LOG_NAME="ESET_SERVER_URL (Forced)"
        else
            FINAL_MIRROR="$CLEAN_RESERVE"
            LOG_NAME="ESET_SERVER_URL_RESERVE"
        fi
    fi

    # --------------------------------------------------------
    # ГЕНЕРАЦИЯ КОНФИГА
    # --------------------------------------------------------
cat <<EOF > nod32ms.conf
[PATCH]
protoscan_v3_patch = 1

[LOG]
generate_web_page = 0
generate_table_only = 0
generate_log_file = 1
log_informativeness = 3
log_level = 0
log_file_size = 0
html_table_path_file = /app/mirror/index.html

[TELEGRAM]
telegram_inform = 0
token =
chat_id =
text =

[SCRIPT]
windows_web_dir = /app/mirror
linux_web_dir = /app/mirror

[CONNECTION]
official_servers_update = 0
mirror = $FINAL_MIRROR
mirror_timeout = 20
mirror_connect_retries = 3
max_workers = 4

# === НАСТРОЙКИ ЛОГИНА И ПАРОЛЯ ===
# mirror_user = $ESET_SERVER_USER
mirror_user = 

# mirror_password = $ESET_SERVER_PASS
mirror_password = 

[ESET]
prefix = data
#versionep12 = 1
versionep13 = 1
EOF

    # --------------------------------------------------------
    # ЗАПУСК ОБНОВЛЕНИЯ
    # --------------------------------------------------------
    echo "=== STARTING SYNC from: $LOG_NAME ===" >> /app/mirror/sync.log

    python -u update.py 2>&1 |
    sed -u -r 's/\x1B[[0-9;]*[[:alpha:]]//g' |
    sed -u "s|$FINAL_MIRROR|ESET_SERVER_URL|g" |
    sed -u -r 's/^\s+//' |
    sed -u '/^$/d' |
    sed -u -e 's/.*Общий прогресс.*/\n==================================================\n= & =\n==================================================/g' |
    tee -a /app/mirror/sync.log
    
    next_time=$(date -d '6 hours' '+%Y-%m-%d %H:%M:%S %Z')
    
    echo "=== FINISHED UPDATE [$RUN_MODE]. Next auto-run: $next_time ===" >> /app/mirror/sync.log
    printf "\n\n\n" >> /app/mirror/sync.log
    
    # --- ОЧИСТКА ЛОГА ---
    python3 /app/filter_logs.py
    # --------------------

    # Сбрасываем триггер, который мог прилететь во время обновления
    rm -f /app/mirror/manual_trigger

    RUN_MODE="AUTO"
    SECONDS_WAITED=0

    while [ $SECONDS_WAITED -lt 21600 ]; do
        if [ -f /app/mirror/manual_trigger ]; then
            rm /app/mirror/manual_trigger
            RUN_MODE="MANUAL"
            echo "=== MANUAL UPDATE REQUESTED ===" >> /app/mirror/sync.log
            break
        fi
        sleep 5
        SECONDS_WAITED=$((SECONDS_WAITED + 5))
    done
done
```

### requirements.txt
```
fastapi
uvicorn[standard]
requests
beautifulsoup4
tqdm
```
