#!/bin/bash

echo "🔄 Инициализация n8n..."

# Создаём и устанавливаем права на /data
chown -R node:node /data
chmod 755 /data

# Проверяем существующую базу данных
if [ -f "/data/database.sqlite" ]; then
    echo "✅ База данных найдена: /data/database.sqlite"
    
    # Проверяем размер файла
    size=$(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null)
    echo "📊 Размер базы данных: $size bytes ($(($size / 1024 / 1024)) MB)"
    
    # Устанавливаем правильные права доступа
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
    
    echo "🔧 Права доступа установлены"
else
    echo "⚠️ База данных не найдена, создаём пустую"
    touch /data/database.sqlite
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
fi

# Создаём директорию для binary данных если её нет
if [ ! -d "/data/binary-data" ]; then
    mkdir -p /data/binary-data
    chown -R node:node /data/binary-data
    chmod 755 /data/binary-data
    echo "📁 Создана директория для binary данных"
fi

echo "🚀 Запускаем n8n как пользователь node..."
exec su-exec node n8n 