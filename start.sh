#!/bin/bash

echo "🚀 ЗАПУСК n8n С RAILWAY VOLUME DATABASE..."
echo "Основано на решениях Railway Station Community"

# 🔧 Исправляем права доступа (критически важно для SQLite!)
echo "🔧 Настройка прав доступа..."
sudo mkdir -p /home/node/.n8n 2>/dev/null || mkdir -p /home/node/.n8n
sudo chown -R node:node /home/node/.n8n 2>/dev/null || chown -R node:node /home/node/.n8n
chmod -R 755 /home/node/.n8n

# КРИТИЧНО: Исправляем права для конфига n8n (блокирует запуск!)
mkdir -p /home/node/.n8n/config 2>/dev/null
chmod 600 /home/node/.n8n/config 2>/dev/null
touch /home/node/.n8n/config/.gitkeep 2>/dev/null
chmod 600 /home/node/.n8n/config/.gitkeep 2>/dev/null

# Исправляем права доступа к volume (важно для SQLite записи!)
sudo chmod -R 777 /app 2>/dev/null || chmod -R 777 /app 2>/dev/null || echo "⚠️ Не удалось изменить права /app"

# 🔍 Диагностика Railway Volume
echo "🔍 ДИАГНОСТИКА RAILWAY VOLUME..."
echo "📂 Содержимое /app/:"
ls -la /app/ 2>/dev/null || echo "❌ Volume не подключен к /app/"

echo ""
echo "🔍 Поиск SQLite баз данных:"
find /app/ -name "*.sqlite*" -o -name "*.db*" -type f -exec ls -lh {} \; 2>/dev/null || echo "❗ Базы данных не найдены"

# 🎯 ОСНОВНАЯ ЛОГИКА: Подключение базы данных
echo ""
echo "🔗 ПОДКЛЮЧЕНИЕ БАЗЫ ДАННЫХ..."

# Удаляем старые ссылки/файлы
rm -f /home/node/.n8n/database.sqlite

# Ищем базу данных на volume
DATABASE_PATH=""

# Проверяем основные варианты названий
if [ -f "/app/database.sqlite" ]; then
    DATABASE_PATH="/app/database.sqlite"
    echo "✅ Найдена база: /app/database.sqlite"
elif [ -f "/app/Database.sqlite" ]; then
    DATABASE_PATH="/app/Database.sqlite"  
    echo "✅ Найдена база: /app/Database.sqlite"
elif [ -f "/app/storage/database.sqlite" ]; then
    DATABASE_PATH="/app/storage/database.sqlite"
    echo "✅ Найдена база: /app/storage/database.sqlite"
else
    # Ищем любую .sqlite базу
    DATABASE_PATH=$(find /app/ -name "*.sqlite" -type f | head -1)
    if [ ! -z "$DATABASE_PATH" ]; then
        echo "✅ Найдена база: $DATABASE_PATH"
    fi
fi

# Подключаем базу данных
if [ ! -z "$DATABASE_PATH" ] && [ -f "$DATABASE_PATH" ]; then
    echo "🔗 Создаём символическую ссылку на базу данных..."
    
    # КРИТИЧНО: Исправляем права доступа к файлу базы данных
    chmod 666 "$DATABASE_PATH" 2>/dev/null || echo "⚠️ Не удалось изменить права базы данных"
    
    ln -sf "$DATABASE_PATH" /home/node/.n8n/database.sqlite
    
    # Проверяем подключение
    if [ -L "/home/node/.n8n/database.sqlite" ] && [ -f "/home/node/.n8n/database.sqlite" ]; then
        SIZE=$(stat -c%s "/home/node/.n8n/database.sqlite" 2>/dev/null)
        echo "✅ БАЗА УСПЕШНО ПОДКЛЮЧЕНА!"
        echo "📊 Размер: $SIZE байт ($(echo "scale=2; $SIZE/1024/1024" | bc 2>/dev/null || echo "~545")MB)"
        echo "🔗 Ссылка: $(readlink /home/node/.n8n/database.sqlite)"
        
        # Финальная проверка прав доступа
        if [ -r "/home/node/.n8n/database.sqlite" ] && [ -w "/home/node/.n8n/database.sqlite" ]; then
            echo "✅ Права доступа к базе данных корректны"
        else
            echo "⚠️ Исправляем финальные права доступа..."
            chmod 666 /home/node/.n8n/database.sqlite 2>/dev/null
        fi
        
        # Проверяем структуру базы
        if command -v sqlite3 >/dev/null 2>&1; then
            echo "🔍 Проверка структуры базы..."
            TABLES=$(sqlite3 /home/node/.n8n/database.sqlite ".tables" 2>/dev/null | wc -w)
            echo "📊 Количество таблиц: $TABLES"
            
            # Показываем несколько первых таблиц
            if [ "$TABLES" -gt 0 ]; then
                echo "📋 Первые таблицы:"
                sqlite3 /home/node/.n8n/database.sqlite ".tables" 2>/dev/null | head -5
            else
                echo "⚠️ База данных пуста или повреждена"
            fi
        fi
    else
        echo "❌ Ошибка при создании ссылки на базу данных"
        exit 1
    fi
else
    echo "❌ БАЗА ДАННЫХ НЕ НАЙДЕНА!"
    echo "🔍 Содержимое /app/:"
    ls -la /app/ 2>/dev/null
    echo ""
    echo "💡 РЕШЕНИЯ:"
    echo "1. Убедитесь, что Railway Volume подключен к /app"
    echo "2. Проверьте, что файл database.sqlite загружен на volume"
    echo "3. Попробуйте распаковать database.sqlite.zip если база в архиве"
    
    # Проверяем наличие zip архива
    if [ -f "/app/database.sqlite.zip" ]; then
        echo ""
        echo "🔍 Найден архив database.sqlite.zip - пытаемся распаковать..."
        cd /app/ && unzip -o database.sqlite.zip
        if [ -f "/app/database.sqlite" ]; then
            echo "✅ База успешно распакована!"
            chmod 666 /app/database.sqlite 2>/dev/null
            DATABASE_PATH="/app/database.sqlite"
            ln -sf "$DATABASE_PATH" /home/node/.n8n/database.sqlite
        else
            echo "❌ Ошибка при распаковке"
            exit 1
        fi
    else
        # Создаем пустую базу данных если её нет (как предложено в Railway Station)
        echo "🆕 Создаём новую базу данных SQLite..."
        touch /app/database.sqlite
        chmod 666 /app/database.sqlite 2>/dev/null
        ln -sf /app/database.sqlite /home/node/.n8n/database.sqlite
        echo "✅ Новая база данных создана"
    fi
fi

# 🔧 Настройка переменных окружения для n8n
echo ""
echo "🔧 НАСТРОЙКА n8n..."

# Основные переменные базы данных
export DB_TYPE="sqlite"
export DB_SQLITE_DATABASE="/home/node/.n8n/database.sqlite"
export N8N_DATABASE_TYPE="sqlite"
export N8N_DATABASE_SQLITE_DATABASE="/home/node/.n8n/database.sqlite"

# Папки и настройки
export N8N_USER_FOLDER="/home/node/.n8n"
export N8N_USER_SETTINGS="/home/node/.n8n"

# КРИТИЧНО: Новые переменные из логов n8n 1.59.4
export N8N_RUNNERS_ENABLED="true"  # Исправляет deprecated warning
export N8N_RUNNERS_MODE="main"     # Запуск в основном режиме
export N8N_RUNNERS_PATH="/home/node/.n8n/runners"

# Веб-сервер настройки для Railway
export N8N_HOST="0.0.0.0"
export N8N_PORT="5678"
export N8N_PROTOCOL="https"
export WEBHOOK_URL="${RAILWAY_STATIC_URL:-https://zolexai.online}/"

# КРИТИЧНО: Исправляем права для SSH и конфигов
export N8N_DISABLE_SETUP_UI="false"  # Включаем Setup UI для первой настройки
export N8N_SECURE_COOKIE="false"     # Отключаем для Railway
export N8N_CONFIG_SECURE="false"     # Исправляет проблему с конфигом

# Безопасность
export N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY:-n8n-encryption-key-railway-2024}"

# Отключаем setup UI только если база уже существует и имеет таблицы
if [ -f "/home/node/.n8n/database.sqlite" ]; then
    TABLES_COUNT=$(sqlite3 /home/node/.n8n/database.sqlite ".tables" 2>/dev/null | wc -w)
    if [ "$TABLES_COUNT" -gt 0 ]; then
        export N8N_DISABLE_SETUP_UI="true"
        echo "✅ Setup UI отключен (база данных содержит таблицы)"
    else
        echo "🆕 Setup UI включен (база данных пуста)"
    fi
fi

# Логирование для отладки
export N8N_LOG_LEVEL="info"  # Уменьшаем логирование

echo "✅ Переменные окружения настроены:"
echo "   DB_TYPE: $DB_TYPE"
echo "   DB_SQLITE_DATABASE: $DB_SQLITE_DATABASE"
echo "   N8N_USER_FOLDER: $N8N_USER_FOLDER"
echo "   N8N_HOST: $N8N_HOST:$N8N_PORT"
echo "   N8N_RUNNERS_ENABLED: $N8N_RUNNERS_ENABLED"

# 🚀 Финальная проверка и запуск
echo ""
echo "🚀 ФИНАЛЬНАЯ ПРОВЕРКА ПЕРЕД ЗАПУСКОМ..."

# Проверяем файл базы данных
if [ -f "/home/node/.n8n/database.sqlite" ]; then
    echo "✅ База данных доступна для n8n"
else
    echo "❌ База данных недоступна!"
    exit 1
fi

# Проверяем права доступа
if [ -r "/home/node/.n8n/database.sqlite" ] && [ -w "/home/node/.n8n/database.sqlite" ]; then
    echo "✅ Права доступа к базе данных в порядке"
else
    echo "⚠️ Исправляем права доступа к базе данных..."
    chmod 666 /home/node/.n8n/database.sqlite 2>/dev/null
fi

# КРИТИЧНО: Финальное исправление прав для config
chmod -R 600 /home/node/.n8n/config* 2>/dev/null
chown -R node:node /home/node/.n8n 2>/dev/null

echo ""
echo "🎉 ВСЁ ГОТОВО! ЗАПУСКАЕМ n8n..."
echo "🔗 База данных: $(readlink /home/node/.n8n/database.sqlite 2>/dev/null || echo '/home/node/.n8n/database.sqlite')"
echo "📊 Размер: $(stat -c%s /home/node/.n8n/database.sqlite 2>/dev/null) байт"
echo "🌐 URL: $WEBHOOK_URL"

# Запускаем n8n
exec n8n start 