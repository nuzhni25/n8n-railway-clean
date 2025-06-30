#!/bin/bash

echo "🔄 Инициализация n8n..."

# Создаём и устанавливаем права на /data
chown -R node:node /data
chmod 755 /data

# Проверяем наличие базы данных
if [ -f "/data/database.sqlite" ]; then
    echo "✅ База данных найдена: $(ls -lh /data/database.sqlite | awk '{print $5}')"
    # Устанавливаем правильные права доступа
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
else
    echo "💡 База данных не найдена, создаём пустую"
    touch /data/database.sqlite
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
fi

echo "🚀 Запускаем n8n как пользователь node..."
exec su-exec node n8n 