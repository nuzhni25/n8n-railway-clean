FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Устанавливаем необходимые пакеты
RUN apk add --no-cache wget curl bash unzip

# Создаем директории для /app (более совместимо с Railway)
RUN mkdir -p /app/.n8n
RUN chown -R node:node /app
RUN chmod -R 755 /app

# Копируем и настраиваем скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh
RUN chown node:node /start.sh

# Переменные среды для /app вместо /data
ENV DB_SQLITE_DATABASE=/app/database.sqlite
ENV N8N_USER_FOLDER=/app/.n8n

USER node

ENTRYPOINT ["/start.sh"]
