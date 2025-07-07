#!/bin/bash

echo "🚀 Starting n8n with Railway Volume database fix..."

# 🎯 CRITICAL FIX: Direct Railway Volume Database Usage
# Based on research, n8n setup screen issue is caused by:
# 1. Multiple conflicting database environment variables
# 2. n8n not recognizing the correct database path
# 3. Encryption key issues
# 4. Permission problems with Railway Volume
# 5. Owner account requirement

# 🔧 Railway Volume Permission Fix
echo "🔧 Fixing Railway Volume permissions..."
if [ "$(whoami)" = "root" ]; then
    echo "✅ Running as root - can fix permissions"
    chown -R 1000:1000 /app/ 2>/dev/null || echo "⚠️ Railway permission restriction"
    chmod -R 755 /app/ 2>/dev/null || echo "⚠️ Railway permission restriction"
    find /app/ -name "*.sqlite*" -exec chmod 664 {} \; 2>/dev/null || echo "⚠️ SQLite file permission restriction"
else
    echo "⚠️ Not running as root - user: $(whoami)"
fi

# 🎯 Railway database detection and setup
echo "🎯 Locating Railway Volume database..."
RAILWAY_DB="/app/database.sqlite"

if [ -f "$RAILWAY_DB" ]; then
    echo "✅ Railway database found: $RAILWAY_DB"
    ls -la "$RAILWAY_DB"
    echo "📊 Database size: $(du -h "$RAILWAY_DB" | cut -f1)"
    
    # 🔍 Database integrity check
    echo "🔍 Checking database integrity..."
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$RAILWAY_DB" "PRAGMA integrity_check;" 2>/dev/null || echo "⚠️ Database integrity check failed"
        echo "📋 Database tables: $(sqlite3 "$RAILWAY_DB" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "Unknown")"
    else
        echo "⚠️ SQLite3 not available for integrity check"
    fi
else
    echo "❌ Railway database not found at $RAILWAY_DB"
    echo "📁 Creating fallback database in home directory"
    mkdir -p /home/node/.n8n
    RAILWAY_DB="/home/node/.n8n/database.sqlite"
fi

# 🔑 Setting encryption key...
echo "🔑 Setting encryption key..."

# 🧹 Clearing conflicting database variables...
echo "🧹 Clearing conflicting database variables..."
unset DB_TYPE
unset N8N_DATABASE_TYPE  
unset N8N_DB_TYPE
unset DATABASE_TYPE

# 🎯 Setting essential database configuration...
echo "🎯 Setting essential database configuration..."
export DB_TYPE="sqlite"
export DB_SQLITE_DATABASE="$RAILWAY_DB"
export N8N_DATABASE_SQLITE_DATABASE="$RAILWAY_DB"
export N8N_USER_FOLDER="/app/.n8n"
export N8N_ENCRYPTION_KEY="HxJKwJEJIamRbyQVmqnQtIenvbF04sNgUK7temfD04tQU7"

# 🎯 CRITICAL: Disable owner account requirement to use existing data
export N8N_OWNER_DISABLED="true"

# 🎯 Optimizing SQLite for Railway environment...
echo "🎯 Optimizing SQLite for Railway environment..."
export N8N_DATABASE_SQLITE_ENABLE_WAL="false"
export N8N_DATABASE_SQLITE_VACUUM_ON_STARTUP="false"

# 🔧 Configuring user folder...
echo "🔧 Configuring user folder..."
mkdir -p /app/.n8n
chown -R 1000:1000 /app/.n8n 2>/dev/null || echo "⚠️ n8n folder permission adjustment skipped"

# 📊 Final verification before starting n8n...
echo "📊 Final verification before starting n8n..."
echo "🗃️ Database path: $DB_SQLITE_DATABASE"
echo "📁 Database exists: $([ -f "$DB_SQLITE_DATABASE" ] && echo "✅ YES" || echo "❌ NO")"
echo "📊 Database readable: $([ -r "$DB_SQLITE_DATABASE" ] && echo "✅ YES" || echo "❌ NO")"

# 🚀 Starting n8n with focused database configuration...
echo "🚀 Starting n8n with focused database configuration..."

# Permissions: 0644 for n8n settings file /home/node/.n8n/.n8n/config are too wide. This is ignored for now, but in the future n8n
# will attempt to change the permissions automatically. To automatically enforce correct permissions now set
# N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true (recommended), or turn this check off set N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false.

exec n8n start 