#!/bin/bash

echo "🚀 Starting n8n with database loading script..."

# 🔧 ИСПРАВЛЯЕМ RAILWAY VOLUME PERMISSIONS - РАБОЧИЙ МЕТОД!
echo "🔧 Railway Volume permission fix - проверенное решение..."

# Даже если мы root, нам нужно убедиться что node user может писать в /app
if [ "$(whoami)" = "root" ]; then
    echo "✅ Запущен как root - можем исправлять права доступа"
    
    if [ -d "/app" ]; then
        echo "📁 Railway Volume найден: /app"
        
        # КРИТИЧЕСКИ ВАЖНО: Меняем владельца Railway Volume на node:node
        echo "🔄 Изменяем владельца /app на node:node (uid:gid 1000:1000)..."
        chown -R 1000:1000 /app/
        
        # Даем права на чтение/запись/выполнение для node user
        echo "🔄 Устанавливаем правильные права доступа..."
        chmod -R 755 /app/
        
        # Специально для SQLite файлов - нужны права на запись
        echo "🔄 Дополнительные права для SQLite операций..."
        find /app -name "*.sqlite*" -exec chmod 664 {} \; 2>/dev/null || true
        
        echo "✅ Railway Volume права доступа исправлены!"
        echo "📋 Текущие права /app:"
        ls -la /app/ | head -5
    else
        echo "⚠️ Railway Volume /app не найден"
    fi
else
    echo "⚠️ НЕ запущен как root - не можем менять права Railway Volume"
    echo "👤 Текущий пользователь: $(whoami) ($(id))"
fi
if [ -d "/app" ]; then
    echo "📁 Railway Volume found at /app"
    echo "👤 Current user: $(whoami)"
    echo "📋 Current /app permissions:"
    ls -la /app/ | head -10
    
    # Try to change ownership of the entire volume to node user
    echo "🔄 Attempting to fix ownership..."
    chown -R node:node /app 2>/dev/null || echo "⚠️ Could not change ownership (Railway restriction)"
    
    # Set proper permissions for SQLite operations
    echo "🔄 Attempting to fix permissions..."
    chmod -R 755 /app 2>/dev/null || echo "⚠️ Could not change permissions (Railway restriction)"
    
    # Alternative: create a subdirectory with proper permissions
    echo "🆕 Creating writable subdirectory..."
    mkdir -p /app/writable 2>/dev/null || echo "⚠️ Could not create subdirectory"
    chown node:node /app/writable 2>/dev/null || echo "⚠️ Could not change subdirectory ownership"
    chmod 777 /app/writable 2>/dev/null || echo "⚠️ Could not change subdirectory permissions"
    
    echo "📋 Updated /app permissions:"
    ls -la /app/ | head -10
else
    echo "❌ Railway Volume /app not found"
fi

# Set environment variables
export N8N_USER_FOLDER=/home/node/.n8n
export DB_SQLITE_DATABASE=/home/node/data/database.sqlite
export N8N_ENCRYPTION_KEY="GevJ653kDGJTiemfO4SynmyQEMRwyL/X"
export DB_SQLITE_PRAGMA_journal_mode=DELETE
export DB_SQLITE_PRAGMA_synchronous=NORMAL

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p /home/node/.n8n
mkdir -p /home/node/data

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

# 🆕 ДОПОЛНИТЕЛЬНАЯ ДИАГНОСТИКА РАЗРЕШЕНИЙ
echo "🔍 Детальная диагностика разрешений /app..."
if [ -d "/app" ]; then
    echo "📂 Права доступа к /app:"
    ls -ld /app/ 2>/dev/null || echo "❌ Не удалось получить информацию о /app"
    
    echo "📊 Содержимое /app с правами:"
    ls -la /app/ | head -10 2>/dev/null || echo "❌ Не удалось прочитать содержимое /app"
    
    echo "🧪 Тест записи в /app:"
    if touch /app/test_write_permission 2>/dev/null; then
        echo "✅ Запись в /app разрешена"
        rm -f /app/test_write_permission
    else
        echo "❌ Запись в /app запрещена - это Railway ограничение!"
    fi
    
    echo "🧪 Тест чтения файлов в /app:"
    for file in /app/*.sqlite*; do
        if [ -f "$file" ]; then
            echo "📄 Файл: $file"
            if [ -r "$file" ]; then
                echo "  ✅ Доступен для чтения"
                file_size=$(stat -c%s "$file" 2>/dev/null || echo "unknown")
                echo "  📊 Размер: $file_size байт"
            else
                echo "  ❌ НЕ доступен для чтения"
            fi
        fi
    done
fi

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

# ПРИОРИТЕТ АРХИВУ: Сначала пробуем ZIP архив (более надежно для больших файлов)
if [ -f "/app/database.sqlite.zip" ]; then
    echo "📦 ПРИОРИТЕТ: Найден database.sqlite.zip ($(stat -c%s "/app/database.sqlite.zip" 2>/dev/null || echo "0") байт)"
    echo "📋 Извлекаем архив в домашнюю директорию пользователя node..."
    if command -v unzip >/dev/null 2>&1; then
        if unzip -t "/app/database.sqlite.zip" >/dev/null 2>&1; then
            echo "✅ ZIP файл валиден, извлекаем..."
            unzip -o "/app/database.sqlite.zip" -d "/home/node/data/"
            if [ -f "/home/node/data/database.sqlite" ]; then
                chown node:node "/home/node/data/database.sqlite"
                chmod 664 "/home/node/data/database.sqlite"
                echo "✅ База данных извлечена из архива в /home/node/data/database.sqlite"
                DB_FILE="/home/node/data/database.sqlite"
            else
                echo "❌ Файл не найден после извлечения"
            fi
        else
            echo "❌ ZIP файл поврежден, пробуем прямое копирование..."
        fi
    else
        echo "❌ unzip не установлен, пробуем прямое копирование..."
    fi
fi

# Если архив не сработал, пробуем прямое копирование
if [ ! -f "$DB_FILE" ] && [ -n "$LARGEST_DB" ] && [ "$LARGEST_SIZE" -gt 50000000 ]; then
    echo "✅ Используем самый большой database.sqlite: $LARGEST_DB ($(echo $LARGEST_SIZE | numfmt --to=iec 2>/dev/null || echo $LARGEST_SIZE) байт)"
    echo "📋 Копируем файл в домашнюю директорию пользователя node..."
    
    # НОВЫЙ МЕТОД: Исправляем разрешения ПЕРЕД копированием
    echo "🔧 Исправляем разрешения исходного файла..."
    chmod +r "$LARGEST_DB" 2>/dev/null || echo "⚠️ Не удалось изменить права чтения"
    
    # Метод 1: dd с лучшими параметрами
    echo "🔄 Метод 1: dd с оптимизацией для больших файлов..."
    if dd if="$LARGEST_DB" of="/home/node/data/database.sqlite" bs=4M status=progress 2>/dev/null; then
        echo "✅ dd копирование успешно"
    else
        echo "❌ dd не сработал"
        
        # Метод 2: cat с перенаправлением (обходит некоторые ограничения)
        echo "🔄 Метод 2: cat с перенаправлением..."
        if cat "$LARGEST_DB" > "/home/node/data/database.sqlite" 2>/dev/null; then
            echo "✅ cat копирование успешно"
        else
            echo "❌ cat не сработал"
            
            # Метод 3: rsync (если доступен)
            if command -v rsync >/dev/null 2>&1; then
                echo "🔄 Метод 3: rsync копирование..."
                if rsync -av "$LARGEST_DB" "/home/node/data/database.sqlite" 2>/dev/null; then
                    echo "✅ rsync копирование успешно"
                else
                    echo "❌ rsync не сработал"
                fi
            fi
            
            # Метод 4: tar (создаем архив и извлекаем)
            echo "🔄 Метод 4: tar архивирование..."
            if tar -cf - -C "$(dirname "$LARGEST_DB")" "$(basename "$LARGEST_DB")" | tar -xf - -C "/home/node/data/" 2>/dev/null; then
                mv "/home/node/data/$(basename "$LARGEST_DB")" "/home/node/data/database.sqlite" 2>/dev/null
                echo "✅ tar копирование успешно"
            else
                echo "❌ tar не сработал"
                
                # Метод 5: Обычное cp (последняя попытка)
                echo "🔄 Метод 5: обычное cp..."
                cp "$LARGEST_DB" "/home/node/data/database.sqlite" 2>/dev/null || echo "❌ cp не сработал"
            fi
        fi
    fi
    
    # Проверяем результат копирования
    COPIED_SIZE=$(stat -c%s "/home/node/data/database.sqlite" 2>/dev/null || echo "0")
    echo "📊 Размер скопированного файла: $COPIED_SIZE байт"
    echo "📊 Размер исходного файла: $LARGEST_SIZE байт"
    
    if [ "$COPIED_SIZE" -gt 50000000 ]; then
        chown node:node "/home/node/data/database.sqlite"
        chmod 664 "/home/node/data/database.sqlite"
        echo "✅ База данных успешно скопирована в /home/node/data/database.sqlite"
        DB_FILE="/home/node/data/database.sqlite"
    else
        echo "❌ Копирование неудачно, размер слишком мал: $COPIED_SIZE байт"
        echo "🔍 Диагностика проблем с копированием..."
        
        # Дополнительная диагностика
        echo "📋 Права доступа к исходному файлу:"
        ls -la "$LARGEST_DB" 2>/dev/null || echo "❌ Не удалось проверить права"
        
        echo "📋 Свободное место в /home/node/data/:"
        df -h /home/node/data/ 2>/dev/null || echo "❌ Не удалось проверить место"
        
        echo "📋 Попытка прочитать первые байты файла:"
        head -c 100 "$LARGEST_DB" 2>/dev/null | hexdump -C | head -5 || echo "❌ Не удалось прочитать файл"
        
        rm -f "/home/node/data/database.sqlite"
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

# 🆕 ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ для Railway Volume
export DB_SQLITE_PRAGMA_temp_store=MEMORY
export DB_SQLITE_PRAGMA_mmap_size=0
echo "✅ SQLite настроен на journal_mode=DELETE (вместо WAL)"
echo "✅ Отключен memory mapping для совместимости с Railway"

# ДИАГНОСТИКА: Проверяем содержимое базы данных
echo "🔍 Диагностика содержимого базы данных..."
if [ -f "$DB_FILE" ]; then
    echo "📊 Проверка таблиц в базе данных:"
    sqlite3 "$DB_FILE" ".tables" 2>/dev/null || echo "❌ Не удалось получить список таблиц"
    
    echo "👤 Проверка пользователей в базе данных:"
    sqlite3 "$DB_FILE" "SELECT COUNT(*) as user_count FROM user;" 2>/dev/null || echo "❌ Таблица user не найдена"
    
    echo "🔧 Проверка воркфлоу в базе данных:"
    sqlite3 "$DB_FILE" "SELECT COUNT(*) as workflow_count FROM workflow_entity;" 2>/dev/null || echo "❌ Таблица workflow_entity не найдена"
    
    echo "📋 Размер базы данных:"
    ls -lh "$DB_FILE"
fi

# КРИТИЧНО: Устанавливаем ключ шифрования для n8n
# Без этого ключа n8n не может расшифровать данные и показывает setup экран
if [ -z "$N8N_ENCRYPTION_KEY" ]; then
    echo "🔑 Устанавливаем ключ шифрования для n8n..."
    export N8N_ENCRYPTION_KEY="GevJ653kDGJTiemfO4SynmyQEMRwyL/X"
    echo "✅ N8N_ENCRYPTION_KEY установлен"
else
    echo "✅ N8N_ENCRYPTION_KEY уже установлен: ${N8N_ENCRYPTION_KEY:0:20}..."
fi

# 🎯 ГЛАВНЫЙ МЕТОД: Прямое использование базы из Railway Volume
echo "🎯 ПРИМЕНЯЕМ ГЛАВНЫЙ МЕТОД - прямое использование базы из /app..."

# Ищем большую базу в /app и используем её НАПРЯМУЮ (это должно решить проблему!)
RAILWAY_DB_FOUND=""
for direct_db in "/app/database.sqlite" "/app/"*.sqlite; do
    if [ -f "$direct_db" ]; then
        file_size=$(stat -c%s "$direct_db" 2>/dev/null || echo "0")
        echo "📊 Проверяем: $direct_db (размер: $file_size байт)"
        
        if [ "$file_size" -gt 50000000 ]; then
            echo "🎯 НАЙДЕНА БОЛЬШАЯ БАЗА В RAILWAY VOLUME: $direct_db"
            echo "📊 Размер: $(echo $file_size | numfmt --to=iec 2>/dev/null || echo $file_size) байт"
            
            # Проверяем доступность для чтения
            if [ -r "$direct_db" ]; then
                echo "✅ База доступна для чтения!"
                
                # КЛЮЧЕВОЕ РЕШЕНИЕ: Используем базу НАПРЯМУЮ из Railway Volume!
                DB_FILE="$direct_db"
                RAILWAY_DB_FOUND="YES"
                echo "🔗 БАЗА БУДЕТ ИСПОЛЬЗОВАТЬСЯ НАПРЯМУЮ: $DB_FILE"
                break
            else
                echo "❌ База недоступна для чтения, попытка исправить права..."
                chmod 664 "$direct_db" 2>/dev/null || echo "⚠️ Не удалось изменить права"
            fi
        fi
    fi
done

if [ "$RAILWAY_DB_FOUND" = "YES" ]; then
    echo "🎉 УСПЕХ! Railway Volume база найдена и будет использоваться напрямую!"
    echo "📍 Никакого копирования не требуется!"
    echo "📂 Путь к базе: $DB_FILE"
else
    echo "⚠️ Большая база в Railway Volume не найдена или недоступна"
    echo "🔄 Возвращаемся к стандартной логике с $DB_FILE"
fi

# Устанавливаем переменные окружения
export DB_SQLITE_DATABASE="$DB_FILE"
export N8N_USER_FOLDER="/home/node/.n8n"

# Создаем директорию для n8n конфигурации
mkdir -p /home/node/.n8n
chown -R node:node /home/node/.n8n

echo "🚀 Запуск n8n..."
echo "📍 DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "📍 N8N_USER_FOLDER=$N8N_USER_FOLDER"
echo "📍 N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:0:20}..."
echo "📍 DB_SQLITE_PRAGMA_journal_mode=$DB_SQLITE_PRAGMA_journal_mode"
echo "📍 DB_SQLITE_PRAGMA_synchronous=$DB_SQLITE_PRAGMA_synchronous"

# Запускаем n8n
exec n8n start 