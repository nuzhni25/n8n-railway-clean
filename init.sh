#!/bin/sh
set -e

echo "📦 Downloading database.zip..."
curl -L 'https://limewire.com/d/H3IAh' -o /app/database.zip

echo "📂 Unzipping to /data..."
mkdir -p /data
unzip -o /app/database.zip -d /data

echo "🚀 Launching n8n..."
exec n8n

