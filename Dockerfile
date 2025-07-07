FROM docker.n8n.io/n8nio/n8n:latest

# Переключаемся на root для установки пакетов
USER root

# Устанавливаем необходимые пакеты
RUN apk add --no-cache \
    wget \
    curl \
    bash \
    unzip \
    file \
    sqlite \
    bc \
    sudo

# Создаем необходимые директории
RUN mkdir -p /app \
    && mkdir -p /home/node/.n8n \
    && chown -R node:node /app \
    && chown -R node:node /home/node/.n8n \
    && chmod -R 755 /app \
    && chmod -R 755 /home/node/.n8n

# Даем пользователю node права sudo (для исправления прав доступа)
RUN echo "node ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Копируем и настраиваем скрипт запуска
COPY start.sh /start.sh
RUN chmod +x /start.sh \
    && chown node:node /start.sh

# Настройка переменных окружения
ENV N8N_USER_FOLDER=/home/node/.n8n
ENV N8N_DATABASE_TYPE=sqlite
ENV DB_TYPE=sqlite

# Переключаемся обратно на пользователя node
USER node

# Устанавливаем точку входа
ENTRYPOINT ["/start.sh"] 
