---
title: ESET Mirror
emoji: 🛡️
colorFrom: gray
colorTo: blue
sdk: docker
pinned: false
---

# ESET Mirror

Docker Space для Hugging Face на базе `Scorpikor/pynod-mirror-tool`.

## Настройка Space

Создай новый Space:

- SDK: **Docker**
- Template: **Blank**

Затем загрузи содержимое этого репозитория.

### Variables / Secrets

В `Settings → Variables and secrets`:

| Переменная | Назначение |
|---|---|
| `ESET_SERVER_URL` | Основной upstream-сервер |
| `ESET_SERVER_URL_RESERVE` | Резервный сервер, необязательно |
| `ESET_SERVER_USER` | Логин, если upstream требует авторизацию |
| `ESET_SERVER_PASS` | Пароль, если upstream требует авторизацию |

Для логина и пароля рекомендуется использовать **Secrets**.

## Эндпоинты

- `/health` — проверка работы контейнера
- `/sync` — запрос ручного обновления
- `/synclog` — журнал последних запусков

Автоматическое обновление выполняется каждые 6 часов.

## Локальная проверка

```bash
docker build -t eset-mirror .
docker run -p 7860:7860 \
  -e ESET_SERVER_URL="https://example.com" \
  eset-mirror
```

После запуска:

- `http://localhost:7860/health`
- `http://localhost:7860/synclog`

## Важно

Используйте только серверы обновлений, учётные данные и лицензии, на использование которых у вас есть разрешение.
