#!/bin/bash

echo "🗜️ СКРИПТ СЖАТИЯ БАЗЫ ДАННЫХ n8n"
echo "=================================="

# Путь к базе данных
DB_PATH="/home/node/.n8n/database.sqlite"
BACKUP_DIR="/app"

# Проверяем, существует ли база данных
if [ ! -f "$DB_PATH" ]; then
    echo "❌ База данных не найдена по пути: $DB_PATH"
    
    # Ищем базу в других местах
    echo "🔍 Поиск базы данных..."
    find /home/node/.n8n/ -name "*.sqlite*" -type f 2>/dev/null || echo "База не найдена в .n8n"
    find /app/ -name "*.sqlite*" -type f 2>/dev/null || echo "База не найдена в /app"
    
    exit 1
fi

# Получаем размер базы данных
DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null)
DB_SIZE_MB=$(echo "scale=2; $DB_SIZE/1024/1024" | bc 2>/dev/null || echo "неизвестно")

echo "📊 Размер базы данных: $DB_SIZE байт (${DB_SIZE_MB}MB)"

# Создаем бэкап
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="database_backup_${TIMESTAMP}.sqlite"
COMPRESSED_NAME="database_backup_${TIMESTAMP}.sqlite.zip"

echo "💾 Создание бэкапа..."
cp "$DB_PATH" "$BACKUP_DIR/$BACKUP_NAME"

if [ -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
    echo "✅ Бэкап создан: $BACKUP_DIR/$BACKUP_NAME"
    
    # Сжимаем бэкап
    echo "🗜️ Сжатие бэкапа..."
    cd "$BACKUP_DIR" && zip -9 "$COMPRESSED_NAME" "$BACKUP_NAME"
    
    if [ -f "$BACKUP_DIR/$COMPRESSED_NAME" ]; then
        COMPRESSED_SIZE=$(stat -c%s "$BACKUP_DIR/$COMPRESSED_NAME" 2>/dev/null)
        COMPRESSED_SIZE_MB=$(echo "scale=2; $COMPRESSED_SIZE/1024/1024" | bc 2>/dev/null || echo "неизвестно")
        
        echo "✅ Сжатый бэкап создан: $BACKUP_DIR/$COMPRESSED_NAME"
        echo "📊 Размер сжатого файла: $COMPRESSED_SIZE байт (${COMPRESSED_SIZE_MB}MB)"
        
        # Удаляем несжатый бэкап
        rm -f "$BACKUP_DIR/$BACKUP_NAME"
        echo "🧹 Несжатый бэкап удален"
        
        # Показываем экономию места
        if [ "$DB_SIZE" -gt 0 ] && [ "$COMPRESSED_SIZE" -gt 0 ]; then
            COMPRESSION_RATIO=$(echo "scale=2; $COMPRESSED_SIZE*100/$DB_SIZE" | bc 2>/dev/null)
            echo "📈 Степень сжатия: ${COMPRESSION_RATIO}%"
        fi
        
    else
        echo "❌ Ошибка при сжатии бэкапа"
        exit 1
    fi
else
    echo "❌ Ошибка при создании бэкапа"
    exit 1
fi

echo ""
echo "🎉 БЭКАП УСПЕШНО СОЗДАН И СЖАТ!"
echo "📁 Файл: $BACKUP_DIR/$COMPRESSED_NAME" 