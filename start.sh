#!/bin/bash

echo "🚀 Запуск n8n с копированием базы из Railway Volume..."

# 🎯 РЕШЕНИЕ: База находится в /app/ (Railway Volume) - копируем её в /home/node/.n8n/
echo "🔍 Поиск базы данных в Railway Volume /app/..."

# Показываем что есть в /app/
echo "📂 Содержимое /app/:"
ls -la /app/ || echo "❌ Нет доступа к /app/"

# 🎯 ОСНОВНОЕ РЕШЕНИЕ: Копируем базу из /app/ в правильное место
if [ -f "/app/database.sqlite" ]; then
    echo "✅ База найдена в /app/database.sqlite"
    
    # Создаём директорию n8n если её нет
    mkdir -p /home/node/.n8n
    
    # Копируем базу данных
    echo "📋 Копируем базу из /app/database.sqlite в /home/node/.n8n/database.sqlite..."
    cp /app/database.sqlite /home/node/.n8n/database.sqlite
    
    # Проверяем размер скопированной базы
    if [ -f "/home/node/.n8n/database.sqlite" ]; then
        SIZE=$(stat -c%s "/home/node/.n8n/database.sqlite")
        echo "✅ База скопирована! Размер: $SIZE байт"
    else
        echo "❌ Ошибка копирования базы!"
    fi
else
    echo "❌ База НЕ найдена в /app/database.sqlite"
    echo "🔍 Поиск базы в других местах в /app/:"
    find /app/ -name "*.sqlite*" -type f 2>/dev/null || echo "Базы не найдены"
fi

# Также проверим есть ли уже база в n8n директории
if [ -f "/home/node/.n8n/database.sqlite" ]; then
    SIZE=$(stat -c%s "/home/node/.n8n/database.sqlite")
    echo "📊 База в /home/node/.n8n/database.sqlite размер: $SIZE байт"
fi

# 🔧 Настройка переменных окружения для n8n
export N8N_DATABASE_SQLITE_DATABASE="/home/node/.n8n/database.sqlite"
export DB_SQLITE_DATABASE="/home/node/.n8n/database.sqlite"
export SQLITE_DATABASE="/home/node/.n8n/database.sqlite"

# Отключаем экран настройки
export N8N_DISABLE_SETUP_UI="true"
export N8N_OWNER_DISABLED="true"

# Ключ шифрования
export N8N_ENCRYPTION_KEY="n8n-encryption-key-railway-2024"

echo "🚀 Запускаем n8n..."
exec n8n 