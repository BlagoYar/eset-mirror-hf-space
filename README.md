---
title: ESET Mirror
sdk: docker
app_port: 7860
---

# ESET Mirror

Hugging Face Docker Space.

## Variables

В Settings → Variables добавьте:

- ESET_SERVER_URL
- ESET_SERVER_URL_RESERVE (если нужен резервный сервер)
- ESET_SERVER_USER (если требуется)
- ESET_SERVER_PASS (если требуется)

## Доступ

- /synclog — лог синхронизации
- /sync — ручной запуск обновления
