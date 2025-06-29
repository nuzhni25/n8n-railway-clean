#!/bin/sh

echo "Fetching database from Dropbox..."
wget -O /data/database.sqlite "https://www.dropbox.com/scl/fi/e1lc8a52t6fv3d86mlwp1/database.sqlite?rlkey=t6t3941pudg4vp0p1h363dcgi&st=7ujvsjme&dl=1"
echo "Done fetching database!"

exec /app/n8n

