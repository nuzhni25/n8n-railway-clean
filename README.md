# n8n Railway Deployment

Развертывание n8n на Railway с автоматической загрузкой существующей базы данных SQLite.

## 🚀 Быстрый старт

1. Клонируйте репозиторий
2. Настройте переменные среды в Railway
3. Подключите к Railway
4. База данных загрузится автоматически в фоне

## 📋 Переменные среды

```env
DATABASE_URL=https://file.kiwi/33ccc9a6#0TVv_YEMbV2tWaivXh5dBA
N8N_ENCRYPTION_KEY=GevJ653kDGJTiemfO4SynmyQEMRwyL/X
```

## 🔧 Настройка Railway

1. **Volume**: Создайте volume с именем `Database-volume` и mount point `/data`
2. **Domain**: Настройте custom domain (например, zolexai.online)

## 📚 Стратегии загрузки базы данных

### 1. 🎯 Текущая стратегия (file.kiwi)
- ✅ Простота - одна ссылка
- ✅ Автоматическая загрузка в фоне
- ⚠️ Размер: 570MB (долгая загрузка)

### 2. 📦 Сжатая база (рекомендуется)
Сжимайте базу перед загрузкой:
```bash
# Локально сжимаем базу
gzip -c database.sqlite > database.sqlite.gz
# Размер уменьшится с 570MB до ~150-200MB
```

Загрузите сжатую версию на file.kiwi и обновите `DATABASE_URL`. 
start.sh автоматически распознает и распакует gzip файлы.

### 3. 🌐 GitHub Releases
```bash
# 1. Добавьте сжатую базу в GitHub Release
gh release create v1.0.0 database.sqlite.gz

# 2. Обновите URL в Railway:
DATABASE_URL=https://github.com/user/repo/releases/download/v1.0.0/database.sqlite.gz
```

### 4. ☁️ Cloud Storage 
```bash
# Google Drive public link
DATABASE_URL=https://drive.google.com/uc?id=FILE_ID

# Dropbox direct link  
DATABASE_URL=https://dl.dropboxusercontent.com/s/TOKEN/database.sqlite.gz
```

## 🔍 Мониторинг

### Railway Logs
```bash
# Ищите эти сообщения:
🚀 Запуск n8n с SQLite...
📝 Создаем временную пустую базу...
🔄 Начинаем фоновую загрузку...
📥 Попытка 1 загрузки базы данных...
📦 Обнаружен сжатый файл, распаковываем...
✅ База данных загружена! Перезапускаем n8n...
```

### Проверка статуса
- **0-30 сек**: n8n доступен (пустая база)
- **5-15 мин**: Загрузка базы в фоне
- **15+ мин**: Перезапуск с полной базой

## 📊 Оптимизация размера базы

### Очистка SQLite
```sql
-- Запустите в SQLite browser перед выгрузкой
VACUUM;
PRAGMA optimize;
```

### Проверка содержимого
```bash
# Размер таблиц
sqlite3 database.sqlite "SELECT name, COUNT(*) FROM sqlite_master WHERE type='table';"

# Самые большие таблицы  
sqlite3 database.sqlite "SELECT name, SUM(pgsize) as size FROM dbstat GROUP BY name ORDER BY size DESC LIMIT 10;"
```

## 🛠️ Альтернативные хостинги

### Render
```yaml
# render.yaml
services:
  - type: web
    name: n8n
    runtime: docker
    dockerfilePath: ./Dockerfile
    envVars:
      - key: DATABASE_URL
        value: https://your-file-url
```

### Heroku
```bash
heroku create your-n8n-app
heroku config:set DATABASE_URL=https://your-file-url
git push heroku main
```

## ❗ Troubleshooting

### База не загружается
1. Проверьте URL в Deploy Logs
2. Убедитесь что файл > 50MB
3. Проверьте доступность ссылки в браузере

### Медленная загрузка
1. Используйте сжатую версию (gzip)
2. Попробуйте другой хостинг файлов
3. Увеличьте таймауты в start.sh

### n8n не видит данные
1. Дождитесь перезапуска после загрузки
2. Проверьте права доступа к файлу
3. Убедитесь в корректности encryption key

## 📝 Структура проекта

```
n8n-railway-clean/
├── Dockerfile          # Docker образ с n8n
├── start.sh            # Скрипт фоновой загрузки БД  
├── railway.json        # Конфигурация Railway
├── README.md           # Эта документация
└── .dockerignore       # Исключения для Docker
```

## 🔗 Полезные ссылки

- [n8n Documentation](https://docs.n8n.io/)
- [Railway Documentation](https://docs.railway.app/)
- [SQLite VACUUM](https://www.sqlite.org/lang_vacuum.html)
- [file.kiwi](https://file.kiwi/) - файловый хостинг 