#!/bin/bash

# Скрипт для сжатия базы данных SQLite для загрузки на Railway
# Использование: ./compress-database.sh database.sqlite

if [ "$#" -ne 1 ]; then
    echo "❌ Использование: $0 <путь_к_database.sqlite>"
    echo "Пример: $0 /path/to/database.sqlite"
    exit 1
fi

DB_PATH="$1"
DB_NAME=$(basename "$DB_PATH")
DB_DIR=$(dirname "$DB_PATH")
COMPRESSED_PATH="${DB_DIR}/${DB_NAME}.gz"

# Проверяем существование файла
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Файл не найден: $DB_PATH"
    exit 1
fi

# Получаем размер исходного файла
ORIGINAL_SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null || echo 0)
ORIGINAL_MB=$((ORIGINAL_SIZE / 1024 / 1024))

echo "📊 Исходный размер: $ORIGINAL_MB MB"
echo "🔄 Сжимаем базу данных..."

# Оптимизируем базу данных перед сжатием
echo "⚡ Оптимизируем SQLite..."
sqlite3 "$DB_PATH" "VACUUM; PRAGMA optimize;"

# Сжимаем с максимальным уровнем сжатия
echo "📦 Сжимаем с gzip..."
gzip -c -9 "$DB_PATH" > "$COMPRESSED_PATH"

if [ $? -eq 0 ]; then
    # Получаем размер сжатого файла
    COMPRESSED_SIZE=$(stat -f%z "$COMPRESSED_PATH" 2>/dev/null || stat -c%s "$COMPRESSED_PATH" 2>/dev/null || echo 0)
    COMPRESSED_MB=$((COMPRESSED_SIZE / 1024 / 1024))
    
    # Вычисляем коэффициент сжатия
    RATIO=$((100 - (COMPRESSED_SIZE * 100 / ORIGINAL_SIZE)))
    
    echo ""
    echo "✅ Сжатие завершено!"
    echo "📁 Исходный файл: $ORIGINAL_MB MB"
    echo "📦 Сжатый файл: $COMPRESSED_MB MB"
    echo "💾 Экономия: $RATIO%"
    echo "📍 Сжатый файл: $COMPRESSED_PATH"
    echo ""
    echo "🚀 Следующие шаги:"
    echo "1. Загрузите $COMPRESSED_PATH на file.kiwi или другой хостинг"
    echo "2. Обновите DATABASE_URL в Railway с новой ссылкой"
    echo "3. start.sh автоматически распознает и распакует gzip файл"
    echo ""
    echo "💡 Время загрузки сократится примерно в $((ORIGINAL_SIZE / COMPRESSED_SIZE)) раза!"
    
else
    echo "❌ Ошибка при сжатии файла"
    exit 1
fi 