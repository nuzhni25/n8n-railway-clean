#!/bin/bash

# Создаем папку, если не существует
mkdir -p /data

# Загружаем базу данных
curl -L "https://www.dropbox.com/scl/fi/e1lc8a52t6fv3d86mlwp1/database.sqlite?rlkey=t6t3941pudg4vp0p1h363dcgi&dl=1" -o /data/database.sqlite

# Права на файл, если нужно
chmod 644 /data/database.sqlite

# Запускаем n8n
exec n8n

