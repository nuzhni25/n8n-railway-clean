#!/bin/bash

echo "🚀 Starting n8n with Railway Volume database fix..."

# 🎯 CRITICAL FIX: Direct Railway Volume Database Usage
# Based on research, n8n setup screen issue is caused by:
# 1. Multiple conflicting database environment variables
# 2. n8n not recognizing the correct database path
# 3. Encryption key issues
# 4. Permission problems with Railway Volume

# 🔧 Railway Volume Permission Fix
echo "🔧 Fixing Railway Volume permissions..."
if [ "$(whoami)" = "root" ]; then
    echo "✅ Running as root - can fix permissions"
    chown -R 1000:1000 /app/ 2>/dev/null || echo "⚠️ Railway permission restriction"
    chmod -R 755 /app/ 2>/dev/null || echo "⚠️ Railway permission restriction"
    find /app -name "*.sqlite*" -exec chmod 664 {} \; 2>/dev/null || true
else
    echo "⚠️ Not running as root - user: $(whoami)"
fi

# 🔍 Locate Railway Volume Database
echo "🔍 Locating Railway Volume database..."
RAILWAY_DB="/app/database.sqlite"
if [ -f "$RAILWAY_DB" ]; then
    DB_SIZE=$(stat -c%s "$RAILWAY_DB" 2>/dev/null || echo "0")
    echo "✅ Found Railway database: $RAILWAY_DB"
    echo "📊 Database size: $(echo $DB_SIZE | numfmt --to=iec 2>/dev/null || echo $DB_SIZE) bytes"
    
    if [ "$DB_SIZE" -gt 50000000 ]; then
        echo "✅ Database size is sufficient (>50MB)"
        
        # Test database accessibility and content
        echo "🔍 Testing database content..."
        TABLE_COUNT=$(sqlite3 "$RAILWAY_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
        echo "📊 Tables in database: $TABLE_COUNT"
        
        if [ "$TABLE_COUNT" -gt 5 ]; then
            echo "🎉 Database contains data - this is the correct database!"
            USE_RAILWAY_DB="YES"
        else
            echo "⚠️ Database appears empty or corrupted"
        fi
    else
        echo "⚠️ Database file too small: $DB_SIZE bytes"
    fi
else
    echo "❌ Railway database not found at $RAILWAY_DB"
fi

# 🎯 Set Database Path
if [ "$USE_RAILWAY_DB" = "YES" ]; then
    echo "🎯 Using Railway Volume database directly"
    DATABASE_PATH="$RAILWAY_DB"
else
    echo "🔄 Creating fallback database in home directory"
    mkdir -p /home/node/data
    DATABASE_PATH="/home/node/data/database.sqlite"
    
    # Try to copy from Railway Volume if it exists
    if [ -f "$RAILWAY_DB" ]; then
        echo "📋 Copying Railway database to home directory..."
        cp "$RAILWAY_DB" "$DATABASE_PATH" 2>/dev/null || echo "⚠️ Copy failed"
        chown node:node "$DATABASE_PATH" 2>/dev/null || true
        chmod 664 "$DATABASE_PATH" 2>/dev/null || true
    fi
fi

# 🔑 CRITICAL: Set Encryption Key
# Research shows this MUST be consistent or n8n shows setup screen
echo "🔑 Setting encryption key..."
export N8N_ENCRYPTION_KEY="GevJ653kDGJTiemfO4SynmyQEMRwyL/X"

# 🗄️ CRITICAL: Clear Database Environment Variables
# Research shows multiple DB variables confuse n8n
echo "🗄️ Clearing conflicting database variables..."
unset DB_SQLITE_DATABASE
unset N8N_DATABASE_SQLITE_DATABASE
unset N8N_DB_SQLITE_DATABASE
unset SQLITE_DATABASE
unset DB_TYPE
unset N8N_DATABASE_TYPE

# 🎯 Set ONLY the essential database variables
echo "🎯 Setting essential database configuration..."
export DB_TYPE="sqlite"
export DB_SQLITE_DATABASE="$DATABASE_PATH"
export N8N_DATABASE_TYPE="sqlite"
export N8N_DATABASE_SQLITE_DATABASE="$DATABASE_PATH"

# 🔧 SQLite Optimization for Railway
echo "🔧 Optimizing SQLite for Railway environment..."
export DB_SQLITE_PRAGMA_journal_mode=DELETE
export DB_SQLITE_PRAGMA_synchronous=NORMAL
export DB_SQLITE_PRAGMA_temp_store=MEMORY
export DB_SQLITE_PRAGMA_mmap_size=0

# 📁 User Folder Configuration
echo "📁 Configuring user folder..."
export N8N_USER_FOLDER="/home/node/.n8n"
mkdir -p /home/node/.n8n
chown -R node:node /home/node/.n8n 2>/dev/null || true

# 🚨 FINAL VERIFICATION
echo "🚨 Final verification before starting n8n..."
echo "📍 Database path: $DATABASE_PATH"
echo "📍 Database exists: $([ -f "$DATABASE_PATH" ] && echo "YES" || echo "NO")"
echo "📍 Database size: $(stat -c%s "$DATABASE_PATH" 2>/dev/null || echo "0") bytes"
echo "📍 Database readable: $([ -r "$DATABASE_PATH" ] && echo "YES" || echo "NO")"

if [ -f "$DATABASE_PATH" ]; then
    FINAL_TABLE_COUNT=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
    echo "📍 Tables in final database: $FINAL_TABLE_COUNT"
    
    # Check for specific n8n tables
    USER_COUNT=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM user;" 2>/dev/null || echo "0")
    WORKFLOW_COUNT=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM workflow_entity;" 2>/dev/null || echo "0")
    echo "📍 Users in database: $USER_COUNT"
    echo "📍 Workflows in database: $WORKFLOW_COUNT"
    
    if [ "$FINAL_TABLE_COUNT" -gt 5 ] && [ "$USER_COUNT" -gt 0 ]; then
        echo "🎉 DATABASE VERIFICATION SUCCESSFUL - Should skip setup screen!"
    else
        echo "⚠️ Database may be empty - setup screen might appear"
    fi
fi

# 📋 Environment Summary
echo "📋 Final environment configuration:"
echo "   DB_TYPE=$DB_TYPE"
echo "   DB_SQLITE_DATABASE=$DB_SQLITE_DATABASE"
echo "   N8N_DATABASE_TYPE=$N8N_DATABASE_TYPE"
echo "   N8N_DATABASE_SQLITE_DATABASE=$N8N_DATABASE_SQLITE_DATABASE"
echo "   N8N_USER_FOLDER=$N8N_USER_FOLDER"
echo "   N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:0:20}..."

echo "🚀 Starting n8n with focused database configuration..."
exec n8n start 