#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

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
        
        # Определяем временный файл
        TEMP_FILE="/data/database_temp.sqlite"
        
        if curl -L --fail --connect-timeout 60 --max-time 1800 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            -H "Accept: */*" \
            --progress-bar \
            -o "$TEMP_FILE" \
            "$DATABASE_URL"; then
            
            # Проверяем размер файла
            FILE_SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE" 2>/dev/null || echo 0)
            echo "📊 Размер загруженного файла: $(($FILE_SIZE / 1024 / 1024)) MB"
            
            # Проверяем минимальный размер (50MB для сжатого файла или 400MB для несжатого)
            MIN_SIZE=50000000
            if [ "$FILE_SIZE" -gt "$MIN_SIZE" ]; then
                echo "✅ База данных загружена! Перезапускаем n8n..."
                
                # Останавливаем n8n
                pkill -f "n8n"
                sleep 5
                
                # Проверяем, является ли файл сжатым (gzip magic number)
                MAGIC=$(head -c 2 "$TEMP_FILE" | hexdump -v -e '/1 "%02x"')
                if [ "$MAGIC" = "1f8b" ]; then
                    echo "📦 Обнаружен сжатый файл, распаковываем..."
                    gunzip -c "$TEMP_FILE" > /data/database.sqlite
                    rm -f "$TEMP_FILE"
                else
                    echo "📁 Обычный файл SQLite"
                    mv "$TEMP_FILE" /data/database.sqlite
                fi
                
                echo "🔄 Перезапускаем n8n с новой базой..."
                exec n8n
            else
                echo "❌ Файл слишком маленький ($(($FILE_SIZE / 1024 / 1024)) MB), повторяем..."
                rm -f "$TEMP_FILE"
            fi
        else
            echo "❌ Ошибка загрузки, попытка $i"
            rm -f "$TEMP_FILE"
        fi
        
        if [ $i -lt 3 ]; then
            echo "⏳ Ждем 60 секунд перед следующей попыткой..."
            sleep 60
        fi
    done
    
    echo "❌ Не удалось загрузить полную базу данных"
    echo "ℹ️  n8n продолжает работать с пустой базой"
}

# Создаем директорию для данных если запускается под root
if [ "$(id -u)" = "0" ]; then
    mkdir -p /data
    chown -R node:node /data
    exec su-exec node "$0" "$@"
fi

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
    if [ "$CURRENT_SIZE" -lt 400000000 ]; then
        echo "📝 База данных неполная ($(($CURRENT_SIZE / 1024 / 1024)) MB), загружаем полную версию в фоне..."
        download_database &
    else
        echo "✅ Полная база данных уже существует ($(($CURRENT_SIZE / 1024 / 1024)) MB)"
    fi
fi

echo "🎯 Запускаем n8n..."
echo "🌐 Будет доступно на порту 5678"
echo "ℹ️  Если база пустая, полная версия загрузится в течение нескольких минут"

# Запускаем n8n
exec n8n 