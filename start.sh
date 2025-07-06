#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

# URL для загрузки базы данных - ОБНОВЛЕННАЯ ССЫЛКА!
DATABASE_URL="${DATABASE_URL:-https://file.kiwi/261a4bdd#5S4OrcMlo5apvO3PvU6c0A}"

# Путь к данным (используем Railway Volume)
DATA_PATH="/data"
DB_PATH="$DATA_PATH/database.sqlite"

# Функция для загрузки базы данных в фоне
download_database() {
    echo "🔄 Начинаем фоновую загрузку ZIP архива базы данных..."
    
    # Ждем пока n8n запустится
    sleep 30
    
    # Пытаемся загрузить архив
    for i in 1 2 3; do
        echo "📦 Попытка $i загрузки ZIP архива..."
        
        # Определяем временный файл для архива
        TEMP_ARCHIVE="$DATA_PATH/database.zip"
        
        if curl -L --fail --connect-timeout 60 --max-time 1800 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            -H "Accept: */*" \
            --progress-bar \
            -o "$TEMP_ARCHIVE" \
            "$DATABASE_URL"; then
            
            # Проверяем что файл загрузился и имеет разумный размер (минимум 10MB для ZIP)
            if [ -f "$TEMP_ARCHIVE" ]; then
                FILE_SIZE=$(stat -c%s "$TEMP_ARCHIVE" 2>/dev/null || echo 0)
                FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))
                
                echo "📊 Размер загруженного архива: ${FILE_SIZE_MB}MB"
                
                if [ "$FILE_SIZE" -gt 10485760 ]; then # > 10MB
                    echo "✅ Архив загружен успешно, начинаем распаковку..."
                    
                    # Распаковываем архив
                    if unzip -q "$TEMP_ARCHIVE" -d "$DATA_PATH/"; then
                        echo "📂 Архив успешно распакован"
                        
                        # Ищем файл database.sqlite в распакованных файлах
                        EXTRACTED_DB=$(find "$DATA_PATH" -name "database.sqlite" -type f | head -1)
                        
                        if [ -n "$EXTRACTED_DB" ] && [ -f "$EXTRACTED_DB" ]; then
                            echo "🗄️ Найдена база данных: $EXTRACTED_DB"
                            
                            # Проверяем размер распакованной базы
                            DB_SIZE=$(stat -c%s "$EXTRACTED_DB" 2>/dev/null || echo 0)
                            DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))
                            
                            echo "📊 Размер базы данных: ${DB_SIZE_MB}MB"
                            
                            if [ "$DB_SIZE" -gt 52428800 ]; then # > 50MB
                                echo "🔄 Заменяем текущую базу данных..."
                                
                                # Останавливаем n8n процесс
                                pkill -f "n8n"
                                sleep 5
                                
                                # Делаем бэкап старой базы
                                if [ -f "$DB_PATH" ]; then
                                    mv "$DB_PATH" "$DB_PATH.backup"
                                fi
                                
                                # Перемещаем новую базу на место
                                mv "$EXTRACTED_DB" "$DB_PATH"
                                
                                # Очищаем временные файлы
                                rm -f "$TEMP_ARCHIVE"
                                
                                echo "✅ База данных успешно обновлена!"
                                echo "🔄 Перезапускаем n8n..."
                                
                                # Перезапускаем n8n
                                exec n8n start
                            else
                                echo "⚠️ Размер распакованной базы слишком мал: ${DB_SIZE_MB}MB"
                            fi
                        else
                            echo "❌ Файл database.sqlite не найден в архиве"
                        fi
                    else
                        echo "❌ Ошибка при распаковке архива"
                    fi
                else
                    echo "⚠️ Размер архива слишком мал: ${FILE_SIZE_MB}MB"
                fi
            fi
            
            # Очищаем временные файлы при ошибке
            rm -f "$TEMP_ARCHIVE"
            break
        else
            echo "❌ Попытка $i неудачна"
            if [ $i -lt 3 ]; then
                echo "⏳ Ждем 60 секунд перед следующей попыткой..."
                sleep 60
            fi
        fi
    done
    
    echo "❌ Не удалось загрузить архив базы данных после 3 попыток"
}

# Создаем необходимые директории
mkdir -p "$DATA_PATH/.n8n"

# Создаем пустую базу данных для быстрого старта
if [ ! -f "$DB_PATH" ]; then
    echo "📝 Создаем пустую базу данных для быстрого старта..."
    touch "$DB_PATH"
fi

echo "🎯 n8n запускается с пустой базой, полная ZIP база загружается в фоне..."

# Запускаем загрузку базы данных в фоне
download_database &

# Запускаем n8n
exec n8n start 