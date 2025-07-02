FROM docker.n8n.io/n8nio/n8n:latest

# Устанавливаем необходимые пакеты включая unzip для ZIP архивов
USER root
RUN apk add --no-cache wget curl su-exec bash unzip

# Создаем рабочие директории в домашней папке node
RUN mkdir -p /home/node/data/.n8n && \
    chown -R node:node /home/node && \
    chmod -R 755 /home/node

# Копируем стартовый скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh && chown node:node /start.sh

# Устанавливаем переменные среды для использования домашней папки
ENV DB_SQLITE_DATABASE=/home/node/data/database.sqlite
ENV N8N_USER_FOLDER=/home/node/data/.n8n

# Возвращаемся к пользователю node
USER node

# Используем ENTRYPOINT для гарантированного запуска
ENTRYPOINT ["/start.sh"] 