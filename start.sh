#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

# URL для загрузки базы данных - ОБНОВЛЕННАЯ ССЫЛКА!
DATABASE_URL="${DATABASE_URL:-https://file.kiwi/261a4bdd#5S4OrcMlo5apvO3PvU6c0A}"

# Путь к данным (используем /app вместо /data для лучшей совместимости с Railway)
DATA_PATH="/app"
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
    if [ -f "$DB_PATH" ]; then
        local db_size=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null || echo "0")
        if [ "$db_size" -gt 52428800 ]; then  # 50MB
            echo "✅ Найдена существующая база данных ($(($db_size / 1024 / 1024))MB)"
            echo "🎯 Используем существующую базу: $DB_PATH"
            return 0
        else
            echo "⚠️ Найден файл базы, но он слишком мал ($db_size байт), удаляем..."
            rm -f "$DB_PATH"
        fi
    fi
    return 1
}

# Функция для загрузки базы данных в фоне
download_database() {
    echo "🔄 Начинаем фоновую загрузку ZIP архива базы данных..."
    
    # Ждем пока n8n запустится
    sleep 30
    
    # Проверяем, не загружена ли уже база
    if check_existing_database; then
        echo "📊 База данных уже существует, пропускаем загрузку"
        return 0
    fi
    
    # Пытаемся загрузить архив
    for i in 1 2 3; do
        echo "📦 Попытка $i загрузки ZIP архива..."
        
        # Определяем временный файл для архива
        TEMP_ARCHIVE="$DATA_PATH/database.zip"
        
        # Проверяем существующий архив
        if [ -f "$TEMP_ARCHIVE" ]; then
            local archive_size=$(stat -f%z "$TEMP_ARCHIVE" 2>/dev/null || stat -c%s "$TEMP_ARCHIVE" 2>/dev/null || echo "0")
            if [ "$archive_size" -gt 10485760 ]; then  # 10MB
                echo "📁 Найден существующий архив ($(($archive_size / 1024 / 1024))MB), используем его"
            else
                echo "⚠️ Архив поврежден ($archive_size байт), удаляем..."
                rm -f "$TEMP_ARCHIVE"
            fi
        fi
        
        # Загружаем архив если его нет
        if [ ! -f "$TEMP_ARCHIVE" ]; then
            if curl -L --fail --connect-timeout 60 --max-time 1800 \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                -o "$TEMP_ARCHIVE" "$DATABASE_URL"; then
                
                local downloaded_size=$(stat -f%z "$TEMP_ARCHIVE" 2>/dev/null || stat -c%s "$TEMP_ARCHIVE" 2>/dev/null || echo "0")
                echo "✅ ZIP архив загружен: $(($downloaded_size / 1024 / 1024))MB"
            else
                echo "❌ Ошибка загрузки архива (попытка $i/3)"
                rm -f "$TEMP_ARCHIVE"
                continue
            fi
        fi
        
        # Распаковываем архив
        echo "📂 Распаковка ZIP архива..."
        if unzip -q -o "$TEMP_ARCHIVE" -d "$DATA_PATH/"; then
            echo "✅ Архив успешно распакован"
            
            # Ищем файл базы данных
            echo "🔍 Поиск файла базы данных..."
            local found_db=$(find "$DATA_PATH" -name "*.sqlite" -type f -size +50M | head -1)
            
            if [ -n "$found_db" ] && [ -f "$found_db" ]; then
                local db_size=$(stat -f%z "$found_db" 2>/dev/null || stat -c%s "$found_db" 2>/dev/null || echo "0")
                echo "🗄️ Найден файл базы: $found_db ($(($db_size / 1024 / 1024))MB)"
                
                # Перемещаем в нужное место если нужно
                if [ "$found_db" != "$DB_PATH" ]; then
                    echo "📋 Перемещение базы в $DB_PATH"
                    mv "$found_db" "$DB_PATH"
                fi
                
                echo "✅ База данных готова к использованию"
                
                # Обновляем переменные среды для n8n
                export DB_SQLITE_DATABASE="$DB_PATH"
                export N8N_USER_FOLDER="$DATA_PATH/.n8n"
                
                echo "🎯 Обновлены переменные среды:"
                echo "   DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
                echo "   N8N_USER_FOLDER=$N8N_USER_FOLDER"
                
                # Перезапускаем n8n
                echo "🔄 Перезапуск n8n с новой базой данных..."
                pkill -f "n8n start" || true
                sleep 5
                
                # Запускаем n8n с новой базой
                echo "🚀 Запуск n8n с загруженной базой данных..."
                exec n8n start
                
            else
                echo "❌ Файл базы данных не найден после распаковки"
            fi
        else
            echo "❌ Ошибка распаковки архива (попытка $i/3)"
        fi
        
        # Удаляем временный архив при ошибке
        rm -f "$TEMP_ARCHIVE"
        sleep 10
    done
    
    echo "❌ Не удалось загрузить базу данных после 3 попыток"
}

# Исправляем права доступа
fix_permissions

echo "🎯 Используем путь: $DATA_PATH"
echo "🎯 База данных: $DB_PATH"
echo "🎯 Переменные среды:"
echo "   DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "   N8N_USER_FOLDER=$N8N_USER_FOLDER"

# Проверяем существующую базу
if check_existing_database; then
    echo "📊 Запускаем n8n с существующей базой данных..."
else
    echo "📊 Запускаем n8n с пустой базой (база будет загружена в фоне)..."
    
    # Запускаем загрузку в фоне
    download_database &
fi

# Запускаем n8n
echo "🚀 Запуск n8n..."
exec n8n start 