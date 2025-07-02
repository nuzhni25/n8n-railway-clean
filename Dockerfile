FROM docker.n8n.io/n8nio/n8n:latest

# Устанавливаем необходимые пакеты
USER root
RUN apk add --no-cache wget curl su-exec bash

# Создаем рабочую директорию для данных
RUN mkdir -p /data && chown node:node /data

# Копируем стартовый скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Устанавливаем переменные среды
ENV DB_SQLITE_DATABASE=/data/database.sqlite
ENV N8N_USER_FOLDER=/data

# Возвращаемся к пользователю node
USER node

# Используем ENTRYPOINT для гарантированного запуска
ENTRYPOINT ["/start.sh"] 