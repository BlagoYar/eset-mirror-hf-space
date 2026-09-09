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
