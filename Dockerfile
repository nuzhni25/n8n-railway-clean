FROM docker.n8n.io/n8nio/n8n:latest

# Устанавливаем необходимые пакеты
USER root
RUN apk add --no-cache wget curl su-exec bash

# Создаем рабочие директории и устанавливаем права
RUN mkdir -p /data/.n8n && \
    chown -R node:node /data && \
    chmod -R 755 /data

# Копируем стартовый скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh && chown node:node /start.sh

# Устанавливаем переменные среды
ENV DB_SQLITE_DATABASE=/data/database.sqlite
ENV N8N_USER_FOLDER=/data/.n8n

# Возвращаемся к пользователю node
USER node

# Создаем директории как пользователь node
RUN mkdir -p /data/.n8n

# Используем ENTRYPOINT для гарантированного запуска
ENTRYPOINT ["/start.sh"] 