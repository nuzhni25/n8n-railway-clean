#!/bin/bash

# Функция для проверки валидности SQLite файла
check_sqlite_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "❌ Файл не найден: $file_path"
        return 1
    fi
    
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    echo "📊 Размер файла: $file_size байт"
    
    # Проверяем размер файла (должен быть больше 50MB для полной базы n8n)
    if [ "$file_size" -lt 52428800 ]; then
        echo "⚠️  Файл слишком маленький (меньше 50MB), возможно поврежден"
        return 1
    fi
    
    # Проверяем SQLite заголовок
    if command -v file >/dev/null 2>&1; then
        local file_type=$(file "$file_path" 2>/dev/null)
        if [[ "$file_type" == *"SQLite"* ]]; then
            echo "✅ SQLite файл валиден"
            return 0
        else
            echo "❌ Файл не является SQLite базой данных"
            return 1
        fi
    fi
    
    # Проверяем SQLite заголовок вручную
    local header=$(head -c 16 "$file_path" 2>/dev/null || echo "")
    if [[ "$header" == "SQLite format 3"* ]]; then
        echo "✅ SQLite файл валиден"
        return 0
    else
        echo "❌ Неверный SQLite заголовок"
        return 1
    fi
}

# Функция для загрузки файла
download_database() {
    local url="$1"
    local output_file="$2"
    
    echo "🔄 Загрузка базы данных из: $url"
    
    # Метод 1: curl
    if command -v curl >/dev/null 2>&1; then
        echo "📥 Попытка загрузки через curl..."
        if curl -L -f --connect-timeout 30 --max-time 300 -o "$output_file" "$url"; then
            echo "✅ Загрузка через curl успешна"
            return 0
        else
            echo "❌ Ошибка загрузки через curl"
            rm -f "$output_file"
        fi
    fi
    
    # Метод 2: wget
    if command -v wget >/dev/null 2>&1; then
        echo "📥 Попытка загрузки через wget..."
        if wget --timeout=30 --tries=3 -O "$output_file" "$url"; then
            echo "✅ Загрузка через wget успешна"
            return 0
        else
            echo "❌ Ошибка загрузки через wget"
            rm -f "$output_file"
        fi
    fi
    
    return 1
}

# Создаем необходимые директории
mkdir -p /app/.n8n

# ИСПРАВЛЯЕМ ПРАВА ДОСТУПА для Railway Volume
echo "🔧 Исправление прав доступа для Railway Volume..."
# Получаем текущего пользователя
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
echo "👤 Текущий пользователь: $CURRENT_USER ($CURRENT_UID:$CURRENT_GID)"

# Изменяем владельца всех файлов в /app на текущего пользователя
chown -R $CURRENT_UID:$CURRENT_GID /app/ 2>/dev/null || {
    echo "⚠️  Не удалось изменить владельца через chown, пробуем альтернативный способ..."
    # Альтернативный способ - копируем файлы с правильными правами
    if [ -f "/app/database.sqlite" ] && [ ! -w "/app/database.sqlite" ]; then
        echo "📋 Копируем database.sqlite с правильными правами..."
        cp /app/database.sqlite /app/database_backup.sqlite
        rm -f /app/database.sqlite
        cp /app/database_backup.sqlite /app/database.sqlite
        rm -f /app/database_backup.sqlite
    fi
}

# Устанавливаем права записи
chmod -R 755 /app/ 2>/dev/null || echo "⚠️  Не удалось изменить права доступа"
chmod 664 /app/database.sqlite 2>/dev/null || echo "⚠️  Не удалось изменить права для database.sqlite"

echo "✅ Права доступа исправлены"

# Проверяем наличие database.sqlite в /app
echo "🔍 Проверка наличия database.sqlite в /app..."

if check_sqlite_file "/app/database.sqlite"; then
    echo "✅ Найден валидный database.sqlite в /app, используем его"
    DB_FILE="/app/database.sqlite"
elif [ -f "/app/database.sqlite.zip" ]; then
    echo "📦 Найден database.sqlite.zip, попытка извлечения..."
    if command -v unzip >/dev/null 2>&1; then
        if unzip -t "/app/database.sqlite.zip" >/dev/null 2>&1; then
            echo "✅ ZIP файл валиден, извлекаем..."
            unzip -o "/app/database.sqlite.zip" -d "/app/"
            if check_sqlite_file "/app/database.sqlite"; then
                echo "✅ База данных успешно извлечена из ZIP"
                DB_FILE="/app/database.sqlite"
            else
                echo "❌ Извлеченный файл поврежден"
            fi
        else
            echo "❌ ZIP файл поврежден"
        fi
    else
        echo "❌ unzip не установлен"
    fi
fi

# Если файл не найден или поврежден, загружаем из интернета
if [ ! -f "$DB_FILE" ] || ! check_sqlite_file "$DB_FILE"; then
    echo "🌐 Загрузка базы данных из интернета..."
    
    # Список URL для загрузки (в порядке приоритета)
    URLS=(
        "https://file.kiwi/33ccc5d8"
        "https://file.kiwi/261a4bdd#5S4OrcMlo5apvO3PvU6c0A"
        "https://file.kiwi/33ccc9a6#0TVv_YEMbV2tWaivXh5dBA"
    )
    
    for url in "${URLS[@]}"; do
        echo "🔄 Попытка загрузки с: $url"
        
        # Загружаем во временный файл
        temp_file="/app/database_temp.sqlite"
        
        if download_database "$url" "$temp_file"; then
            # Проверяем загруженный файл
            if check_sqlite_file "$temp_file"; then
                mv "$temp_file" "/app/database.sqlite"
                echo "✅ База данных успешно загружена и установлена"
                DB_FILE="/app/database.sqlite"
                break
            else
                echo "❌ Загруженный файл поврежден"
                rm -f "$temp_file"
            fi
        else
            echo "❌ Не удалось загрузить с: $url"
        fi
    done
    
    # Если все загрузки не удались, создаем пустую базу
    if [ ! -f "$DB_FILE" ]; then
        echo "⚠️  Не удалось загрузить базу данных, n8n создаст новую"
        touch /app/database.sqlite
        DB_FILE="/app/database.sqlite"
    fi
fi

echo "🎯 Используемая база данных: $DB_FILE"
echo "📊 Финальный размер файла: $(stat -c%s "$DB_FILE" 2>/dev/null || echo "0") байт"

# Устанавливаем переменные окружения
export DB_SQLITE_DATABASE="$DB_FILE"
export N8N_USER_FOLDER="/app/.n8n"

echo "🚀 Запуск n8n..."
echo "📍 DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "📍 N8N_USER_FOLDER=$N8N_USER_FOLDER"

# Запускаем n8n
exec n8n start 