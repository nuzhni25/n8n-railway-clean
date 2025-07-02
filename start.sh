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
            
            # Проверяем размер загруженного файла
            DOWNLOADED_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || stat -f%z "$TEMP_FILE" 2>/dev/null || echo 0)
            DOWNLOADED_MB=$((DOWNLOADED_SIZE / 1024 / 1024))
            
            echo "📊 Размер загруженного файла: $DOWNLOADED_MB MB"
            
            # Проверяем что файл достаточно большой (минимум 100MB)
            if [ "$DOWNLOADED_SIZE" -gt 104857600 ]; then
                # Определяем тип файла по magic numbers
                FILE_TYPE=$(file -b "$TEMP_FILE" | head -1)
                echo "📋 Тип файла: $FILE_TYPE"
                
                # Проверяем, является ли файл сжатым
                if echo "$FILE_TYPE" | grep -qi "gzip"; then
                    echo "📦 Обнаружен сжатый файл, распаковываем..."
                    if gunzip -c "$TEMP_FILE" > "/data/database.sqlite.tmp"; then
                        mv "/data/database.sqlite.tmp" "/data/database.sqlite"
                        echo "✅ Сжатая база данных успешно распакована!"
                    else
                        echo "❌ Ошибка при распаковке сжатого файла"
                        continue
                    fi
                else
                    # Файл не сжат, просто перемещаем
                    mv "$TEMP_FILE" "/data/database.sqlite"
                    echo "✅ База данных загружена!"
                fi
                
                echo "🔄 Перезапускаем n8n с новой базой данных..."
                
                # Отправляем сигнал для перезапуска n8n
                pkill -f "n8n"
                
                return 0
            else
                echo "⚠️ Загруженный файл слишком маленький: $DOWNLOADED_MB MB, ожидаем минимум 100MB"
                rm -f "$TEMP_FILE"
            fi
        else
            echo "❌ Попытка $i не удалась"
        fi
        
        if [ $i -lt 3 ]; then
            echo "⏳ Ждем 60 секунд перед следующей попыткой..."
            sleep 60
        fi
    done
    
    echo "❌ Не удалось загрузить базу данных после 3 попыток"
}

# Создаем пустую базу данных если её нет
if [ ! -f "/data/database.sqlite" ]; then
    echo "📝 Создаем пустую базу данных для быстрого старта..."
    touch "/data/database.sqlite" || echo "⚠️ Не удалось создать файл базы данных"
fi

echo "💾 База данных используется из: /data/database.sqlite"
echo "🌐 n8n будет доступен на порту 5678"

# Запускаем загрузку базы данных в фоне
download_database &

# Запускаем n8n
echo "🚀 Запускаем n8n..."
exec n8n start 