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

# НОВЫЙ ПОДХОД: Копируем файл из /app в домашнюю директорию пользователя
echo "🔍 Диагностика содержимого волуме /app..."

# Показываем все файлы в /app
echo "📋 Содержимое /app:"
ls -la /app/ 2>/dev/null || echo "Директория /app пуста или недоступна"

# Показываем размеры всех файлов
echo "📊 Размеры файлов в /app:"
find /app -type f -exec ls -lh {} \; 2>/dev/null || echo "Файлы не найдены"

# Ищем все файлы .sqlite в /app
echo "🔍 Поиск всех .sqlite файлов в /app:"
find /app -name "*.sqlite*" -exec ls -lh {} \; 2>/dev/null || echo "SQLite файлы не найдены"

# Создаем директорию для базы данных в домашней папке
mkdir -p /home/node/data

# Ищем самый большой SQLite файл в /app
LARGEST_DB=""
LARGEST_SIZE=0

for db_file in "/app/database.sqlite" "/app/"*.sqlite; do
    if [ -f "$db_file" ]; then
        file_size=$(stat -c%s "$db_file" 2>/dev/null || echo "0")
        echo "📊 Найден файл: $db_file (размер: $file_size байт)"
        if [ "$file_size" -gt "$LARGEST_SIZE" ]; then
            LARGEST_SIZE="$file_size"
            LARGEST_DB="$db_file"
        fi
    fi
done

if [ -n "$LARGEST_DB" ] && [ "$LARGEST_SIZE" -gt 50000000 ]; then
    echo "✅ Используем самый большой database.sqlite: $LARGEST_DB ($(echo $LARGEST_SIZE | numfmt --to=iec 2>/dev/null || echo $LARGEST_SIZE) байт)"
    echo "📋 Копируем файл в домашнюю директорию пользователя node..."
    cp "$LARGEST_DB" "/home/node/data/database.sqlite"
    chown node:node "/home/node/data/database.sqlite"
    chmod 664 "/home/node/data/database.sqlite"
    echo "✅ База данных скопирована в /home/node/data/database.sqlite"
    DB_FILE="/home/node/data/database.sqlite"
elif [ -f "/app/database.sqlite.zip" ]; then
    echo "📦 Найден database.sqlite.zip ($(stat -c%s "/app/database.sqlite.zip" 2>/dev/null || echo "0") байт)"
    echo "📋 Извлекаем архив в домашнюю директорию пользователя node..."
    if command -v unzip >/dev/null 2>&1; then
        if unzip -t "/app/database.sqlite.zip" >/dev/null 2>&1; then
            echo "✅ ZIP файл валиден, извлекаем..."
            unzip -o "/app/database.sqlite.zip" -d "/home/node/data/"
            if [ -f "/home/node/data/database.sqlite" ]; then
                chown node:node "/home/node/data/database.sqlite"
                chmod 664 "/home/node/data/database.sqlite"
                echo "✅ База данных извлечена в /home/node/data/database.sqlite"
                DB_FILE="/home/node/data/database.sqlite"
            else
                echo "❌ Файл не найден после извлечения"
            fi
        else
            echo "❌ ZIP файл поврежден"
        fi
    else
        echo "❌ unzip не установлен"
    fi
fi

# Если файл не найден, создаем пустую базу в домашней директории
if [ ! -f "$DB_FILE" ]; then
    echo "⚠️  Файлы в /app не найдены или повреждены, создаем новую базу данных"
    touch "/home/node/data/database.sqlite"
    chown node:node "/home/node/data/database.sqlite"
    chmod 664 "/home/node/data/database.sqlite"
    DB_FILE="/home/node/data/database.sqlite"
fi

echo "🎯 Используемая база данных: $DB_FILE"
echo "📊 Финальный размер файла: $(stat -c%s "$DB_FILE" 2>/dev/null || echo "0") байт"

# ИСПРАВЛЕНИЕ: Отключаем WAL режим для избежания проблем с правами доступа
echo "🔧 Настройка SQLite для избежания проблем с правами доступа..."
export DB_SQLITE_PRAGMA_journal_mode=DELETE
export DB_SQLITE_PRAGMA_synchronous=NORMAL
echo "✅ SQLite настроен на journal_mode=DELETE (вместо WAL)"

# Устанавливаем переменные окружения
export DB_SQLITE_DATABASE="$DB_FILE"
export N8N_USER_FOLDER="/home/node/.n8n"

# Создаем директорию для n8n конфигурации
mkdir -p /home/node/.n8n
chown -R node:node /home/node/.n8n

echo "🚀 Запуск n8n..."
echo "📍 DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "📍 N8N_USER_FOLDER=$N8N_USER_FOLDER"
echo "📍 DB_SQLITE_PRAGMA_journal_mode=$DB_SQLITE_PRAGMA_journal_mode"
echo "📍 DB_SQLITE_PRAGMA_synchronous=$DB_SQLITE_PRAGMA_synchronous"

# Запускаем n8n
exec n8n start 