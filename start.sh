#!/bin/bash
set -u

export TZ="${TZ:-Europe/Kyiv}"
export PYTHONIOENCODING=utf-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

MIRROR_DIR="/app/mirror"
LOG_FILE="$MIRROR_DIR/sync.log"
TRIGGER_FILE="$MIRROR_DIR/manual_trigger"
APP_DIR="/app/pynod"

mkdir -p "$MIRROR_DIR/data" "$MIRROR_DIR/eset_upd"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE" || true

log() {
    echo "$*" >> "$LOG_FILE"
}

# --- webhook для ручного запуска ---
cat > /app/webhook.py <<'PY'
from http.server import HTTPServer, BaseHTTPRequestHandler

TRIGGER = "/app/mirror/manual_trigger"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with open(TRIGGER, "w", encoding="utf-8") as f:
            f.write("1")

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(b"Manual update requested. Check /synclog\n")

    def log_message(self, fmt, *args):
        pass

HTTPServer(("127.0.0.1", 9999), Handler).serve_forever()
PY

python3 /app/webhook.py &
WEBHOOK_PID=$!

cleanup() {
    kill "$WEBHOOK_PID" 2>/dev/null || true
    nginx -s quit 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# --- очистка логов: оставить 6 последних запусков ---
cat > /app/filter_logs.py <<'PY'
import os
import re

path = "/app/mirror/sync.log"

if not os.path.exists(path):
    raise SystemExit(0)

with open(path, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

parts = re.split(r"(=== PREPARING UPDATE \[.*?===)", content)
blocks = []

for i in range(1, len(parts), 2):
    header = parts[i]
    body = parts[i + 1] if i + 1 < len(parts) else ""
    blocks.append(header + body)

with open(path, "w", encoding="utf-8") as f:
    f.write(parts[0] + "".join(blocks[-6:]))
PY

SCRIPT_PATH=$(find "$APP_DIR" -name "update.py" -print -quit)

if [ -z "$SCRIPT_PATH" ]; then
    log "CRITICAL: update.py not found!"
else
    cd "$(dirname "$SCRIPT_PATH")"
fi

# nginx в foreground-процессе, чтобы Space корректно отслеживал контейнер
nginx -g 'daemon off;' &
NGINX_PID=$!

rm -f "$TRIGGER_FILE"

get_datetime() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

RUN_MODE="AUTO"

while true; do
    log "=== PREPARING UPDATE [$RUN_MODE] $(get_datetime) ==="

    CLEAN_URL=$(echo "${ESET_SERVER_URL:-}" | xargs)
    CLEAN_RESERVE=$(echo "${ESET_SERVER_URL_RESERVE:-}" | xargs)

    if [ -z "$CLEAN_URL" ]; then
        log "[ERROR] ESET_SERVER_URL is empty. Waiting 6 hours or manual trigger."
        FINAL_MIRROR=""
        LOG_NAME="NOT CONFIGURED"
    else
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" -m 10 -L "$CLEAN_URL" || true)
        HTTP_CODE=${HTTP_CODE:-000}

        if [ "$HTTP_CODE" != "000" ]; then
            FINAL_MIRROR="$CLEAN_URL"
            LOG_NAME="ESET_SERVER_URL"
            log "[CHECK] Primary ONLINE. HTTP $HTTP_CODE"
        elif [ -n "$CLEAN_RESERVE" ]; then
            FINAL_MIRROR="$CLEAN_RESERVE"
            LOG_NAME="ESET_SERVER_URL_RESERVE"
            log "[CHECK] Primary unavailable. Switching to reserve."
        else
            FINAL_MIRROR="$CLEAN_URL"
            LOG_NAME="ESET_SERVER_URL (forced)"
            log "[WARNING] Primary unavailable and reserve is empty."
        fi
    fi

    if [ -n "${FINAL_MIRROR:-}" ] && [ -n "${SCRIPT_PATH:-}" ]; then
        cat > nod32ms.conf <<EOF
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
mirror_user = ${ESET_SERVER_USER:-}
mirror_password = ${ESET_SERVER_PASS:-}

[ESET]
prefix = data
versionep13 = 1
EOF

        log "=== STARTING SYNC from: $LOG_NAME ==="

        python -u update.py 2>&1 \
            | sed -u -r 's/\x1B\[[0-9;]*[[:alpha:]]//g' \
            | sed -u -r 's/^\s+//' \
            | sed -u '/^$/d' \
            | sed -u -e 's/.*Общий прогресс.*/\n==================================================\n= & =\n==================================================/g' \
            | tee -a "$LOG_FILE"

        log "=== FINISHED UPDATE [$RUN_MODE] ==="
        python3 /app/filter_logs.py
    fi

    RUN_MODE="AUTO"
    SECONDS_WAITED=0

    while [ "$SECONDS_WAITED" -lt 21600 ]; do
        if [ -f "$TRIGGER_FILE" ]; then
            rm -f "$TRIGGER_FILE"
            RUN_MODE="MANUAL"
            log "=== MANUAL UPDATE REQUESTED ==="
            break
        fi

        if ! kill -0 "$NGINX_PID" 2>/dev/null; then
            log "CRITICAL: nginx stopped."
            cleanup
        fi

        sleep 5
        SECONDS_WAITED=$((SECONDS_WAITED + 5))
    done
done
