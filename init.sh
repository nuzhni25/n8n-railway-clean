#!/bin/sh

echo "🔁 Fetching database from Dropbox..."
wget -O /data/database.sqlite "https://dl.dropboxusercontent.com/scl/fi/e1lc8a52t6fv3d86mlwp1/database.sqlite?rlkey=t6t3941pudg4vp0p1h363dcgi&dl=1"
echo "✅ Done fetching database!"

# Запускаем n8n
exec n8n

