#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

# URL для загрузки базы данных - ОБНОВЛЕННАЯ ССЫЛКА!
DATABASE_URL="${DATABASE_URL:-https://file.kiwi/261a4bdd#5S4OrcMlo5apvO3PvU6c0A}"

# Путь к данным (используем Railway Volume)
DATA_PATH="/data"
DB_PATH="$DATA_PATH/database.sqlite"

# Функция для исправления прав доступа
fix_permissions() {
    echo "🔧 Исправляем права доступа..."
    
    # Создаем директории если их нет
    mkdir -p "$DATA_PATH/.n8n" 2>/dev/null || true
    
    # Пытаемся исправить права как root если возможно
    if [ "$(id -u)" = "0" ]; then
        chown -R node:node "$DATA_PATH" 2>/dev/null || true
        chmod -R 755 "$DATA_PATH" 2>/dev/null || true
    fi
    
    # Проверяем доступ на запись
    if [ ! -w "$DATA_PATH" ]; then
        echo "⚠️ Нет прав записи в $DATA_PATH, используем домашнюю папку"
        DATA_PATH="/home/node/data"
        DB_PATH="$DATA_PATH/database.sqlite"
        mkdir -p "$DATA_PATH/.n8n"
        
        # Обновляем переменные среды
        export DB_SQLITE_DATABASE="$DB_PATH"
        export N8N_USER_FOLDER="$DATA_PATH/.n8n"
        
        echo "🔄 Переменные среды обновлены:"
        echo "   DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
        echo "   N8N_USER_FOLDER=$N8N_USER_FOLDER"
    fi
}

# Функция для проверки существующей базы данных
check_existing_database() {
    echo "🔍 Проверяем существующую базу данных..."
    
    if [ -f "$DB_PATH" ]; then
        DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
        DB_SIZE_MB=$((DB_SIZE / 1024 / 1024))
        
        echo "📊 Найдена база данных: $DB_PATH (${DB_SIZE_MB}MB)"
        
        # Если база больше 50MB, считаем её полной
        if [ "$DB_SIZE" -gt 52428800 ]; then
            echo "✅ База данных уже загружена и готова к использованию!"
            return 0
        else
            echo "⚠️ База данных слишком мала (${DB_SIZE_MB}MB), нужна загрузка"
            return 1
        fi
    else
        echo "❌ База данных не найдена, нужна загрузка"
        return 1
    fi
}

# Функция для загрузки базы данных в фоне
download_database() {
    echo "🔄 Начинаем фоновую загрузку ZIP архива базы данных..."
    
    # Проверяем, не загружена ли уже база
    if check_existing_database; then
        echo "🎯 База уже загружена, пропускаем загрузку"
        return 0
    fi
    
    # Ждем пока n8n запустится
    sleep 30
    
    # Пытаемся загрузить архив
    for i in 1 2 3; do
        echo "📦 Попытка $i загрузки ZIP архива..."
        
        # Определяем временный файл для архива
        TEMP_ARCHIVE="$DATA_PATH/database.zip"
        
        # Проверяем, не загружен ли уже архив
        if [ -f "$TEMP_ARCHIVE" ]; then
            echo "📋 Найден существующий архив, проверяем..."
            FILE_SIZE=$(stat -c%s "$TEMP_ARCHIVE" 2>/dev/null || echo 0)
            if [ "$FILE_SIZE" -gt 10485760 ]; then
                echo "✅ Используем существующий архив"
            else
                echo "⚠️ Архив поврежден, удаляем"
                rm -f "$TEMP_ARCHIVE"
            fi
        fi
        
        # Загружаем архив если его нет
        if [ ! -f "$TEMP_ARCHIVE" ]; then
            if curl -L --fail --connect-timeout 60 --max-time 1800 \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                -H "Accept: */*" \
                --progress-bar \
                -o "$TEMP_ARCHIVE" \
                "$DATABASE_URL"; then
                
                echo "✅ Архив загружен успешно"
            else
                echo "❌ Ошибка загрузки архива"
                continue
            fi
        fi
        
        # Проверяем загруженный архив
        if [ -f "$TEMP_ARCHIVE" ]; then
            FILE_SIZE=$(stat -c%s "$TEMP_ARCHIVE" 2>/dev/null || echo 0)
            FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))
            
            echo "📊 Размер архива: ${FILE_SIZE_MB}MB"
            
            if [ "$FILE_SIZE" -gt 10485760 ]; then # > 10MB
                echo "✅ Архив корректный, начинаем распаковку..."
                
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
                            
                            # Исправляем права на новую базу
                            chmod 644 "$DB_PATH" 2>/dev/null || true
                            
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
    done
    
    echo "❌ Не удалось загрузить архив базы данных после 3 попыток"
}

# Исправляем права доступа
fix_permissions

echo "🎯 Используем путь: $DATA_PATH"
echo "🎯 База данных: $DB_PATH"
echo "🎯 Переменные среды:"
echo "   DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "   N8N_USER_FOLDER=$N8N_USER_FOLDER"

# Проверяем существующую базу данных
if ! check_existing_database; then
    # Создаем пустую базу данных для быстрого старта
    echo "📝 Создаем пустую базу данных для быстрого старта..."
    touch "$DB_PATH" 2>/dev/null || echo "⚠️ Не удалось создать файл базы"
    
    echo "🎯 n8n запускается с пустой базой, полная ZIP база загружается в фоне..."
    
    # Запускаем загрузку базы данных в фоне
    download_database &
else
    echo "🎯 n8n запускается с существующей базой данных"
fi

# Запускаем n8n
exec n8n start 