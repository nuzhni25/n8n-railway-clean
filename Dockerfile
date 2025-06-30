FROM n8nio/n8n

# Устанавливаем переменную для правильных прав доступа к Volume
ENV RAILWAY_RUN_UID=0

# Устанавливаем wget для загрузки файлов
USER root
RUN apk add --no-cache wget su-exec

# Создаём директорию для данных и устанавливаем права
RUN mkdir -p /data && chown -R node:node /data

# Создаём startup скрипт прямо в Dockerfile
RUN echo '#!/bin/bash\n\
echo "🔄 Инициализация n8n..."\n\
chown -R node:node /data\n\
chmod 755 /data\n\
if [ ! -f "/data/database.sqlite" ] && [ ! -z "$DATABASE_URL" ]; then\n\
    echo "📥 Загружаем базу данных с $DATABASE_URL"\n\
    wget --timeout=300 --tries=3 -O /data/database.sqlite "$DATABASE_URL"\n\
    if [ -f "/data/database.sqlite" ]; then\n\
        size=$(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null)\n\
        echo "📊 Размер файла: $size bytes"\n\
        if [ "$size" -gt 500000000 ]; then\n\
            echo "✅ База загружена"\n\
            chown node:node /data/database.sqlite\n\
            chmod 644 /data/database.sqlite\n\
        else\n\
            echo "⚠️ Файл неполный, создаём пустую базу"\n\
            rm -f /data/database.sqlite\n\
            touch /data/database.sqlite\n\
            chown node:node /data/database.sqlite\n\
        fi\n\
    fi\n\
elif [ ! -f "/data/database.sqlite" ]; then\n\
    echo "💡 Создаём пустую базу"\n\
    touch /data/database.sqlite\n\
    chown node:node /data/database.sqlite\n\
fi\n\
echo "🚀 Запускаем n8n..."\n\
exec su-exec node n8n\n' > /start.sh && chmod +x /start.sh

# Указываем рабочую директорию
WORKDIR /home/node

# Запускаем startup скрипт
CMD ["/start.sh"] 