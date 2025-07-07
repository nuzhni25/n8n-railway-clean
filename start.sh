#!/bin/bash

echo "🚀 Starting n8n with Railway Volume database copy..."

# 🎯 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: КОПИРОВАНИЕ БАЗЫ ИЗ VOLUME 
# Проблема: база в /app/database.sqlite но n8n не может её использовать из-за разрешений
# Решение: копируем базу в /home/node/.n8n/database.sqlite где n8n может с ней работать

# 🔧 Настройка разрешений для пользователя node
echo "🔧 Настройка разрешений..."
if [ "$(whoami)" = "root" ]; then
    echo "✅ Работаем от root - можем исправить разрешения"
    chown -R 1000:1000 /app/ 2>/dev/null || echo "⚠️ Ограничение Railway для /app/"
    chmod -R 755 /app/ 2>/dev/null || echo "⚠️ Ограничение Railway для /app/"
else
    echo "⚠️ Не root пользователь: $(whoami)"
fi

# 🎯 Поиск базы данных в Railway Volume
echo "🎯 Поиск базы данных в Railway Volume..."
VOLUME_DB="/app/database.sqlite"
TARGET_DB="/home/node/.n8n/database.sqlite"

# 📁 Создание целевой директории
echo "📁 Создание директории для n8n..."
mkdir -p /home/node/.n8n
chown -R 1000:1000 /home/node/.n8n 2>/dev/null || echo "⚠️ Не удалось изменить владельца"
chmod -R 755 /home/node/.n8n 2>/dev/null || echo "⚠️ Не удалось изменить права"

if [ -f "$VOLUME_DB" ]; then
    echo "✅ База найдена в Volume: $VOLUME_DB"
    echo "📊 Размер базы в Volume: $(du -h "$VOLUME_DB" | cut -f1)"
    
    # 🔄 КРИТИЧЕСКИ ВАЖНО: КОПИРОВАНИЕ БАЗЫ
    echo "🔄 КОПИРОВАНИЕ базы из Volume в рабочую директорию..."
    echo "   Источник: $VOLUME_DB"
    echo "   Назначение: $TARGET_DB"
    
    # Принудительное копирование
    cp "$VOLUME_DB" "$TARGET_DB" 2>/dev/null
    COPY_RESULT=$?
    
    if [ $COPY_RESULT -eq 0 ] && [ -f "$TARGET_DB" ]; then
        echo "✅ База УСПЕШНО скопирована!"
        echo "📊 Размер скопированной базы: $(du -h "$TARGET_DB" | cut -f1)"
        
        # Исправление разрешений скопированной базы
        chown 1000:1000 "$TARGET_DB" 2>/dev/null || echo "⚠️ Не удалось изменить владельца базы"
        chmod 664 "$TARGET_DB" 2>/dev/null || echo "⚠️ Не удалось изменить права базы"
        
        # Проверка целостности скопированной базы
        if command -v sqlite3 >/dev/null 2>&1; then
            TABLE_COUNT=$(sqlite3 "$TARGET_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
            echo "📋 Таблиц в скопированной базе: $TABLE_COUNT"
            
            if [ "$TABLE_COUNT" -gt 5 ]; then
                echo "🎉 База содержит данные - копирование успешно!"
                USE_COPIED_DB="YES"
            else
                echo "⚠️ Скопированная база пустая"
            fi
        fi
    else
        echo "❌ ОШИБКА копирования базы!"
        echo "Создаём новую базу..."
    fi
else
    echo "❌ База НЕ найдена в Volume: $VOLUME_DB"
    echo "Будет создана новая база..."
fi

# 🔑 КРИТИЧЕСКИ ВАЖНО: Постоянный ключ шифрования
echo "🔑 Установка ключа шифрования..."
export N8N_ENCRYPTION_KEY="GevJ653kDGJTiemfO4SynmyQEMRwyL/X"

# 🧹 Очистка конфликтующих переменных
echo "🧹 Очистка переменных базы данных..."
unset DB_SQLITE_DATABASE
unset N8N_DATABASE_SQLITE_DATABASE 
unset N8N_DB_SQLITE_DATABASE
unset SQLITE_DATABASE
unset DB_TYPE
unset N8N_DATABASE_TYPE
unset N8N_DB_TYPE

# 🎯 Настройка ТОЛЬКО необходимых переменных для скопированной базы
echo "🎯 Настройка базы данных..."
export DB_TYPE="sqlite"
export DB_SQLITE_DATABASE="$TARGET_DB"
export N8N_DATABASE_SQLITE_DATABASE="$TARGET_DB"
export N8N_USER_FOLDER="/home/node/.n8n"

# 🚫 ОТКЛЮЧЕНИЕ ЭКРАНА НАСТРОЙКИ
echo "🚫 Отключение экрана настройки..."
export N8N_OWNER_DISABLED="true"
export N8N_DISABLE_SETUP_UI="true"

# ⚡ Оптимизация SQLite
echo "⚡ Оптимизация SQLite..."
export N8N_DATABASE_SQLITE_ENABLE_WAL="false"
export N8N_DATABASE_SQLITE_VACUUM_ON_STARTUP="false"

# 📊 Финальная проверка перед запуском
echo "📊 Финальная проверка..."
echo "🗃️ Путь к базе: $DB_SQLITE_DATABASE"
echo "📁 База существует: $([ -f "$DB_SQLITE_DATABASE" ] && echo "✅ ДА" || echo "❌ НЕТ")"
echo "📊 База читаемая: $([ -r "$DB_SQLITE_DATABASE" ] && echo "✅ ДА" || echo "❌ НЕТ")"

# 🔄 ОЖИДАНИЕ ПОЛНОГО КОПИРОВАНИЯ
echo "🔄 Проверяем что база полностью скопировалась..."
if [ -f "$DB_SQLITE_DATABASE" ]; then
    FINAL_SIZE=$(stat -c%s "$DB_SQLITE_DATABASE" 2>/dev/null || echo "0")
    echo "📊 Финальный размер базы: $FINAL_SIZE байт"
    
    if [ "$FINAL_SIZE" -gt 1000000 ]; then
        echo "✅ База достаточно большая - готова к использованию"
    else
        echo "⚠️ База маленькая - возможно копирование не завершено"
        sleep 2
    fi
fi

# 🚀 ЗАПУСК N8N
echo "🚀 Запуск n8n с правильной базой данных..."
echo "   Используется база: $DB_SQLITE_DATABASE"
echo "   Ключ шифрования установлен"
echo "   Экран настройки отключен"

exec n8n start 