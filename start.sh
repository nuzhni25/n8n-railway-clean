#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

# Переключаемся на root для операций с файлами
if [ "$(id -u)" != "0" ]; then
    exec su-exec root "$0" "$@"
fi

# Создаем директорию для данных если не существует
mkdir -p /data
chown node:node /data

# URL для загрузки базы данных из переменной среды или по умолчанию
DATABASE_URL="${DATABASE_URL:-https://file.kiwi/33ccc9a6#0TVv_YEMbV2tWaivXh5dBA}"

# Функция для загрузки базы данных в фоне
download_database() {
    echo "🔄 Начинаем фоновую загрузку базы данных..."
    
    # Ждем пока n8n запустится
    sleep 30
    
    # Пытаемся загрузить базу данных
    for i in 1 2 3; do
        echo "📥 Попытка $i загрузки базы данных..."
        
        if curl -L --fail --connect-timeout 60 --max-time 1800 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            -H "Accept: */*" \
            --progress-bar \
            -o /data/database_new.sqlite \
            "$DATABASE_URL"; then
            
            # Проверяем размер файла
            FILE_SIZE=$(stat -f%z /data/database_new.sqlite 2>/dev/null || stat -c%s /data/database_new.sqlite 2>/dev/null || echo 0)
            echo "📊 Размер загруженного файла: $(($FILE_SIZE / 1024 / 1024)) MB"
            
            if [ "$FILE_SIZE" -gt 500000000 ]; then
                echo "✅ База данных загружена! Перезапускаем n8n..."
                # Останавливаем n8n, заменяем базу и перезапускаем
                pkill -f "n8n"
                sleep 5
                mv /data/database_new.sqlite /data/database.sqlite
                chown node:node /data/database.sqlite
                chmod 644 /data/database.sqlite
                echo "🔄 Перезапускаем n8n с новой базой..."
                su-exec node n8n &
                break
            else
                echo "❌ Файл слишком маленький, повторяем..."
                rm -f /data/database_new.sqlite
            fi
        else
            echo "❌ Ошибка загрузки, попытка $i"
            rm -f /data/database_new.sqlite
        fi
        
        if [ $i -lt 3 ]; then
            echo "⏳ Ждем 60 секунд перед следующей попыткой..."
            sleep 60
        fi
    done
    
    if [ ! -f "/data/database.sqlite" ] || [ $(stat -f%z /data/database.sqlite 2>/dev/null || stat -c%s /data/database.sqlite 2>/dev/null || echo 0) -lt 500000000 ]; then
        echo "❌ Не удалось загрузить полную базу данных"
        echo "ℹ️  n8n продолжает работать с пустой базой"
    fi
}

# Проверяем, существует ли полная база данных
if [ ! -f "/data/database.sqlite" ]; then
    echo "📝 Создаем временную пустую базу для быстрого старта..."
    touch /data/database.sqlite
    
    # Запускаем загрузку в фоне
    download_database &
    
    echo "ℹ️  n8n запускается с пустой базой, полная база загружается в фоне..."
else
    # Проверяем размер существующей базы
    CURRENT_SIZE=$(stat -f%z /data/database.sqlite 2>/dev/null || stat -c%s /data/database.sqlite 2>/dev/null || echo 0)
    if [ "$CURRENT_SIZE" -lt 500000000 ]; then
        echo "📝 База данных неполная ($(($CURRENT_SIZE / 1024 / 1024)) MB), загружаем полную версию в фоне..."
        download_database &
    else
        echo "✅ Полная база данных уже существует ($(($CURRENT_SIZE / 1024 / 1024)) MB)"
    fi
fi

# Устанавливаем правильные права на файлы
chown -R node:node /data
chmod 644 /data/database.sqlite

echo "🎯 Запускаем n8n..."
echo "🌐 Будет доступно на порту 5678"
echo "ℹ️  Если база пустая, полная версия загрузится в течение нескольких минут"

# Переключаемся на пользователя node и запускаем n8n
exec su-exec node n8n 