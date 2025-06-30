#!/bin/bash

echo "🔄 Инициализация n8n..."

# Создаём и устанавливаем права на /data
chown -R node:node /data
chmod 755 /data

# Проверяем, есть ли уже база в Volume
if [ ! -f "/data/database.sqlite" ] && [ ! -z "$DATABASE_URL" ]; then
    echo "📥 Загружаем базу данных с $DATABASE_URL"
    
    # Загружаем базу
    wget --timeout=300 --tries=3 -O /data/database.sqlite "$DATABASE_URL"
    
    if [ -f "/data/database.sqlite" ]; then
        size=$(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null)
        echo "📊 Размер файла: $size bytes"
        
        if [ "$size" -gt 500000000 ]; then
            echo "✅ База загружена успешно"
            chown node:node /data/database.sqlite
            chmod 644 /data/database.sqlite
        else
            echo "⚠️ Файл загружен не полностью, создаём пустую базу"
            rm -f /data/database.sqlite
            touch /data/database.sqlite
            chown node:node /data/database.sqlite
            chmod 644 /data/database.sqlite
        fi
    else
        echo "❌ Не удалось загрузить файл"
        touch /data/database.sqlite
        chown node:node /data/database.sqlite
        chmod 644 /data/database.sqlite
    fi
elif [ ! -f "/data/database.sqlite" ]; then
    echo "💡 Создаём пустую базу (DATABASE_URL не задана)"
    touch /data/database.sqlite
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
else
    echo "✅ База данных уже существует"
    # Проверяем права доступа
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
fi

echo "🚀 Запускаем n8n как пользователь node..."
exec su-exec node n8n 