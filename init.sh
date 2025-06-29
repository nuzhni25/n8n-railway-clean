#!/bin/bash
set -e

echo "📥 Downloading database.zip..."
curl -L 'https://limewire.com/d/H3IAh#BRCTO77IFt' -o /app/database.zip

echo "📦 Unzipping to /data..."
mkdir -p /data
unzip -o /app/database.zip -d /data

echo "🚀 Launching n8n..."
n8n
# dummy change to force commit

