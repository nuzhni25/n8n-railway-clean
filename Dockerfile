FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Устанавливаем необходимые пакеты
RUN apk add --no-cache wget curl bash unzip

# Создаем директории для Railway Volume
RUN mkdir -p /data/.n8n
RUN chown -R node:node /data
RUN chmod -R 755 /data

# Копируем и настраиваем скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh
RUN chown node:node /start.sh

# Переменные среды для Railway Volume
ENV DB_SQLITE_DATABASE=/data/database.sqlite
ENV N8N_USER_FOLDER=/data/.n8n

USER node

ENTRYPOINT ["/start.sh"]
