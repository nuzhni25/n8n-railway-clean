# 🗄️ Руководство по хостингу базы данных SQLite

Данное руководство описывает различные способы размещения базы данных SQLite для загрузки в Railway.

## 📦 Подготовка базы данных

### 1. Сжатие базы (Рекомендуется)

```bash
# Используйте наш скрипт
./compress-database.sh /path/to/database.sqlite

# Или вручную:
gzip -c -9 database.sqlite > database.sqlite.gz
```

**Преимущества сжатия:**
- Размер уменьшается в 3-4 раза (570MB → 150MB)
- Быстрая загрузка по сети
- Экономия трафика и времени

## 🌐 Варианты хостинга

### 1. 📁 file.kiwi (Текущий)
**Преимущества:** Простота, анонимность, без регистрации
**Недостатки:** Ограниченное время жизни (90 часов)

```bash
# Ваша текущая ссылка
DATABASE_URL=https://file.kiwi/33ccc9a6#0TVv_YEMbV2tWaivXh5dBA
```

### 2. 🐙 GitHub Releases (Лучший выбор)
**Преимущества:** Бесплатно, надежно, постоянно, версионирование
**Недостатки:** Публичный доступ

```bash
# 1. Создайте release в вашем репозитории
gh release create v1.0.0 database.sqlite.gz --notes "Initial database"

# 2. Получите прямую ссылку
DATABASE_URL=https://github.com/USER/REPO/releases/download/v1.0.0/database.sqlite.gz
```

### 3. 📂 Google Drive
**Преимущества:** 15GB бесплатно, простота
**Недостатки:** Иногда блокируется, требует настройки

```bash
# 1. Загрузите файл в Google Drive
# 2. Сделайте его публичным (Anyone with the link)
# 3. Используйте прямую ссылку:
DATABASE_URL=https://drive.google.com/uc?id=ФАЙЛ_ID&export=download
```

**Как получить ID файла:**
- Ссылка Google Drive: `https://drive.google.com/file/d/1ABC123xyz/view`
- Файл ID: `1ABC123xyz`

### 4. 📦 Dropbox
**Преимущества:** Простота, надежность
**Недостатки:** Ограниченное место (2GB)

```bash
# 1. Загрузите файл в Dropbox
# 2. Создайте публичную ссылку
# 3. Замените ?dl=0 на ?dl=1:
DATABASE_URL=https://dl.dropboxusercontent.com/s/TOKEN/database.sqlite.gz?dl=1
```

### 5. ☁️ AWS S3 (Для продакшена)
**Преимущества:** Максимальная надежность, CDN
**Недостатки:** Платно (но дешево)

```bash
# 1. Создайте S3 bucket
aws s3 mb s3://my-n8n-database

# 2. Загрузите файл с публичным доступом
aws s3 cp database.sqlite.gz s3://my-n8n-database/ --acl public-read

# 3. Используйте ссылку
DATABASE_URL=https://my-n8n-database.s3.amazonaws.com/database.sqlite.gz
```

### 6. 🖇️ WeTransfer / SendAnywhere
**Преимущества:** Большие файлы, без регистрации  
**Недостатки:** Временные ссылки (7 дней)

```bash
# Подходит для экстренных случаев
DATABASE_URL=https://we.tl/t-XXXXXXXXXX
```

## 🔧 Настройка в Railway

```bash
# В Variables & Secrets Railway:
DATABASE_URL=https://ваша-ссылка-здесь

# Примеры:
DATABASE_URL=https://github.com/user/repo/releases/download/v1.0.0/database.sqlite.gz
DATABASE_URL=https://drive.google.com/uc?id=1ABC123xyz&export=download  
DATABASE_URL=https://dl.dropboxusercontent.com/s/token/database.sqlite.gz?dl=1
```

## 📊 Сравнение вариантов

| Сервис | Бесплатно | Размер | Время жизни | Скорость | Рекомендация |
|--------|-----------|---------|-------------|----------|-------------|
| **GitHub Releases** | ✅ | 2GB | ♾️ | ⚡⚡⚡ | 🌟 **Лучший** |
| file.kiwi | ✅ | ♾️ | 90 часов | ⚡⚡ | 👍 Хорошо |
| Google Drive | ✅ | 15GB | ♾️ | ⚡ | 👍 Хорошо |
| Dropbox | ✅ | 2GB | ♾️ | ⚡⚡ | 👍 Хорошо |
| AWS S3 | 💰 | ♾️ | ♾️ | ⚡⚡⚡ | 🚀 Продакшен |

## 🛡️ Безопасность

### Шифрование базы данных
```bash
# Перед загрузкой зашифруйте базу
gpg --symmetric --cipher-algo AES256 database.sqlite.gz

# В start.sh добавьте расшифровку:
echo "YOUR_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --decrypt database.sqlite.gz.gpg | gunzip > /data/database.sqlite
```

### Переменные среды
```bash
# Не храните пароли в коде, используйте переменные Railway:
GPG_PASSWORD=your-secret-password
DATABASE_URL=https://your-encrypted-database.gpg
```

## 🔄 Обновление базы данных

### Автоматическое обновление через GitHub Actions

```yaml
# .github/workflows/update-database.yml
name: Update Database
on:
  schedule:
    - cron: '0 2 * * *'  # Каждый день в 2 утра
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Download from production
        run: |
          # Скачайте базу с продакшен сервера
          curl -o database.sqlite https://your-n8n.com/backup/database
      - name: Compress and release
        run: |
          gzip -9 database.sqlite
          gh release create "db-$(date +%Y%m%d)" database.sqlite.gz
```

## 📈 Мониторинг загрузки

### Логи Railway
Ищите эти сообщения в Deploy Logs:
```bash
📥 Попытка 1 загрузки базы данных...
📊 Размер загруженного файла: 150 MB
📦 Обнаружен сжатый файл, распаковываем...
✅ База данных загружена! Перезапускаем n8n...
```

### Проверка статуса
```bash
# Проверьте доступность ссылки
curl -I "https://your-database-url"

# Проверьте размер файла
curl -sI "https://your-database-url" | grep -i content-length
```

## 🚨 Troubleshooting

### Файл не скачивается
1. **Проверьте ссылку в браузере** - должна начаться загрузка
2. **Убедитесь в публичном доступе** - никаких авторизаций
3. **Проверьте user-agent** - некоторые сервисы блокируют curl

### Медленная загрузка
1. **Используйте CDN** (CloudFlare, AWS CloudFront)
2. **Выберите ближайший регион** к датацентру Railway
3. **Сжимайте файлы** с максимальным уровнем

### База не применяется
1. **Дождитесь перезапуска** после сообщения "✅ База данных загружена!"
2. **Проверьте encryption key** - должен совпадать с исходным
3. **Проверьте права на файл** в логах Railway

## 💡 Лучшие практики

1. **Всегда сжимайте базу** перед загрузкой
2. **Используйте GitHub Releases** для постоянного хранения  
3. **Создавайте бэкапы** в нескольких местах
4. **Версионируйте базы** по датам
5. **Мониторьте логи** Railway для отслеживания процесса
6. **Тестируйте ссылки** перед деплоем

## 🔗 Полезные команды

```bash
# Проверка размера сжатой базы
ls -lh database.sqlite.gz

# Тест распаковки
gunzip -t database.sqlite.gz

# Создание чексуммы для проверки целостности  
sha256sum database.sqlite.gz

# Быстрый тест загрузки
time curl -o /dev/null "https://your-database-url"
``` 