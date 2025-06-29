ARG CACHE_BREAK=29-06-2025
FROM node:20-slim

# Устанавливаем unzip, curl
RUN apt-get update && apt-get install -y curl unzip
# Копируем скрипт и устанавливаем права
COPY init.sh /app/init.sh
RUN chmod +x /app/init.sh

# Устанавливаем n8n
RUN npm install -g n8n

# Устанавливаем переменную окружения для SQLite
ENV DB_TYPE=sqlite
ENV DB_SQLITE_DATABASE=/data/database.sqlite

# Устанавливаем рабочую директорию
WORKDIR /data

# Запускаем скрипт
CMD ["/app/init.sh"]

