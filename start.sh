#!/bin/bash

echo "🚀 Запуск n8n с SQLite..."

# URLs для загрузки базы данных - несколько вариантов
DATABASE_URLS=(
    "${DATABASE_URL:-https://file.kiwi/261a4bdd#5S4OrcMlo5apvO3PvU6c0A}"
    "https://file.kiwi/33ccc9a6#0TVv_YEMbV2tWaivXh5dBA"
)

# Путь к данным (используем /app для лучшей совместимости с Railway)
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
    echo "🔄 Начинаем фоновую загрузку базы данных SQLite..."
    
    # Ждем пока n8n запустится
    sleep 30
    
    # Проверяем, не загружена ли уже база
    if check_existing_database; then
        echo "📊 База данных уже существует, пропускаем загрузку"
        return 0
    fi
    
    # Пытаемся загрузить с разных URL
    for url in "${DATABASE_URLS[@]}"; do
        echo "🌐 Пробуем загрузить с: $url"
        
        for i in 1 2 3; do
            echo "📦 Попытка $i загрузки SQLite файла..."
            
            # Определяем временный файл
            TEMP_DB="$DATA_PATH/database_temp.sqlite"
            
            # Пробуем разные методы загрузки
            local download_success=false
            
            # Метод 1: curl с прямой загрузкой
            echo "🔽 Метод 1: Прямая загрузка через curl..."
            if curl -L --fail --connect-timeout 60 --max-time 1800 \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                -o "$TEMP_DB" "$url"; then
                
                local downloaded_size=$(stat -f%z "$TEMP_DB" 2>/dev/null || stat -c%s "$TEMP_DB" 2>/dev/null || echo "0")
                echo "✅ Файл загружен: $(($downloaded_size / 1024 / 1024))MB"
                
                if [ "$downloaded_size" -gt 52428800 ]; then  # 50MB
                    download_success=true
                else
                    echo "⚠️ Файл слишком мал ($downloaded_size байт)"
                    rm -f "$TEMP_DB"
                fi
            else
                echo "❌ Ошибка загрузки через curl"
            fi
            
            # Метод 2: wget как резерв
            if [ "$download_success" = false ]; then
                echo "🔽 Метод 2: Загрузка через wget..."
                if command -v wget >/dev/null 2>&1; then
                    if wget --timeout=60 --tries=3 --user-agent="Mozilla/5.0" \
                        -O "$TEMP_DB" "$url"; then
                        
                        local downloaded_size=$(stat -f%z "$TEMP_DB" 2>/dev/null || stat -c%s "$TEMP_DB" 2>/dev/null || echo "0")
                        echo "✅ Файл загружен через wget: $(($downloaded_size / 1024 / 1024))MB"
                        
                        if [ "$downloaded_size" -gt 52428800 ]; then  # 50MB
                            download_success=true
                        else
                            echo "⚠️ Файл слишком мал ($downloaded_size байт)"
                            rm -f "$TEMP_DB"
                        fi
                    else
                        echo "❌ Ошибка загрузки через wget"
                    fi
                else
                    echo "⚠️ wget не установлен"
                fi
            fi
            
            # Проверяем успешность загрузки
            if [ "$download_success" = true ] && [ -f "$TEMP_DB" ]; then
                # Проверяем, что это действительно SQLite файл
                echo "🔍 Проверяем формат файла..."
                if file "$TEMP_DB" | grep -i sqlite >/dev/null 2>&1 || \
                   head -c 16 "$TEMP_DB" | grep -q "SQLite format" 2>/dev/null; then
                    
                    echo "✅ Подтвержден SQLite формат"
                    
                    # Перемещаем файл на место
                    echo "📋 Устанавливаем базу данных..."
                    mv "$TEMP_DB" "$DB_PATH"
                    
                    # Проверяем права доступа
                    chmod 644 "$DB_PATH" 2>/dev/null || true
                    
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
                    echo "❌ Файл не является SQLite базой данных"
                    rm -f "$TEMP_DB"
                fi
            fi
            
            # Пауза перед следующей попыткой
            sleep 10
        done
        
        echo "⚠️ Не удалось загрузить с $url, пробуем следующий URL..."
    done
    
    echo "❌ Не удалось загрузить базу данных ни с одного URL"
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