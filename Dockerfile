FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Устанавливаем необходимые пакеты
RUN apk add --no-cache wget curl bash unzip

# Создаем директории
RUN mkdir -p /home/node/data/.n8n
RUN chown -R node:node /home/node
RUN chmod -R 755 /home/node

# Копируем и настраиваем скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh
RUN chown node:node /start.sh

# Переменные среды
ENV DB_SQLITE_DATABASE=/home/node/data/database.sqlite
ENV N8N_USER_FOLDER=/home/node/data/.n8n

USER node

ENTRYPOINT ["/start.sh"]
