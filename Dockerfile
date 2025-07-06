FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Устанавливаем необходимые пакеты
RUN apk add --no-cache wget curl bash unzip

# Создаем директории для Railway Volume и резервную в домашней папке
RUN mkdir -p /data/.n8n /home/node/data/.n8n
RUN chown -R node:node /data /home/node 2>/dev/null || true
RUN chmod -R 755 /data /home/node 2>/dev/null || true

# Копируем и настраиваем скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh
RUN chown node:node /start.sh

# Переменные среды для Railway Volume (могут быть переопределены в скрипте)
ENV DB_SQLITE_DATABASE=/data/database.sqlite
ENV N8N_USER_FOLDER=/data/.n8n

USER node

ENTRYPOINT ["/start.sh"]
