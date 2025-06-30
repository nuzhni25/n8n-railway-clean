#!/bin/bash

echo "🔄 Инициализация n8n..."

# Создаём и устанавливаем права на /data
mkdir -p /data
chown -R node:node /data
chmod 755 /data

# Проверяем, есть ли уже база в Volume
if [ ! -f "/data/database.sqlite" ]; then
    echo "📥 Загружаем базу данных..."
    
    # Если есть переменная с URL базы
    if [ ! -z "$DATABASE_URL" ]; then
        echo "🌐 Скачиваем базу с $DATABASE_URL"
        
        # Попытки загрузки с retry
        for i in {1..3}; do
            echo "🔄 Попытка загрузки $i/3..."
            
            # Загружаем с timeout и resume
            wget --timeout=300 --tries=3 --continue -O /data/database.sqlite "$DATABASE_URL"
            
            # Проверяем размер файла (ожидаем ~545MB = 545000000 bytes)
            if [ -f "/data/database.sqlite" ]; then
                size=$(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null)
                echo "📊 Размер загруженного файла: $size bytes"
                
                if [ "$size" -gt 500000000 ]; then
                    echo "✅ База данных загружена полностью"
                    chown node:node /data/database.sqlite
                    chmod 644 /data/database.sqlite
                    break
                else
                    echo "⚠️ Файл загружен не полностью (размер: $size), повторяем..."
                    rm -f /data/database.sqlite
                fi
            else
                echo "❌ Файл не создан, повторяем..."
            fi
            
            sleep 5
        done
        
        # Финальная проверка
        if [ ! -f "/data/database.sqlite" ] || [ $(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null) -lt 500000000 ]; then
            echo "❌ Не удалось загрузить базу данных полностью"
            echo "💡 Создаём пустую базу..."
            rm -f /data/database.sqlite
            touch /data/database.sqlite
            chown node:node /data/database.sqlite
            chmod 644 /data/database.sqlite
        fi
    else
        echo "💡 Переменная DATABASE_URL не найдена, создаём пустую базу"
        touch /data/database.sqlite
        chown node:node /data/database.sqlite
        chmod 644 /data/database.sqlite
    fi
else
    echo "✅ База данных уже существует"
    size=$(stat -c%s "/data/database.sqlite" 2>/dev/null || stat -f%z "/data/database.sqlite" 2>/dev/null)
    echo "📊 Размер существующей базы: $size bytes"
    # Убеждаемся что права правильные
    chown node:node /data/database.sqlite
    chmod 644 /data/database.sqlite
fi

echo "🚀 Запускаем n8n как пользователь node..."
# Переключаемся на пользователя node и запускаем n8n
exec su-exec node "$@" 