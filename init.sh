#!/bin/sh

echo "⬇️ Скачиваем базу данных..."
curl -L "https://files.fm/u/9kq79ka5us" -o /data/database.sqlite

echo "✅ Файл скачан. Запускаем n8n..."
exec n8n

