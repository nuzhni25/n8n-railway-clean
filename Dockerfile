FROM n8nio/n8n:latest

USER root

# Устанавливаем только su-exec
RUN apk add --no-cache su-exec

# Копируем startup скрипт
COPY start.sh /start.sh
RUN chmod +x /start.sh && ls -la /start.sh

# Переменные окружения
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=https
ENV DB_TYPE=sqlite
ENV DB_SQLITE_DATABASE=/data/database.sqlite
ENV DB_SQLITE_VACUUM_ON_STARTUP=true
ENV N8N_DIAGNOSTICS_ENABLED=false
ENV N8N_VERSION_NOTIFICATIONS_ENABLED=false
ENV N8N_ENCRYPTION_KEY=defaultencryptionkey
ENV RAILWAY_RUN_UID=0

# Создаём директорию data и устанавливаем права
RUN mkdir -p /data && chown -R node:node /data

EXPOSE 5678

CMD ["sh", "/start.sh"]
