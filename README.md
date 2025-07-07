прпо# n8n Railway Deployment

Развертывание n8n на Railway с автоматической загрузкой существующей базы данных SQLite из ZIP архива.

## 🚀 Быстрый старт

1. Клонируйте репозиторий
2. Настройте переменные среды в Railway
3. Подключите к Railway
4. ZIP архив базы данных загрузится автоматически в фоне

## 📋 Переменные среды

```env
DATABASE_URL=https://file.kiwi/35654c19#q6Laai6wTToRYFghXf2lhQ
N8N_ENCRYPTION_KEY=GevJ653kDGJTiemfO4SynmyQEMRwyL/X
```

## 🔧 Настройка Railway

1. **Volume**: Создайте volume с именем `Database-volume` и mount point `/data`
2. **Domain**: Настройте custom domain (например, zolexai.online)

## 📦 Новая ZIP стратегия (АКТИВНА)

### ✅ **Преимущества ZIP архива:**
- **Размер уменьшен в 3-4 раза** (570MB SQLite → ~150MB ZIP)
- **Быстрая загрузка** - меньше времени ожидания
- **Автоматическая распаковка** - unzip встроен в контейнер
- **Поиск базы** - автоматически ищет database.sqlite в архиве

### 🎯 **Как это работает:**
1. **n8n стартует мгновенно** с пустой базой 
2. **ZIP архив загружается в фоне** (~5-10 минут вместо 20+)
3. **Автоматическая распаковка** и поиск database.sqlite
4. **Замена базы и перезапуск** n8n с полными данными

## 📚 Создание ZIP архива

```bash
# Из SQLite базы данных
zip -9 database.zip database.sqlite

# Или используйте наш скрипт
./compress-database.sh /path/to/database.sqlite
```

## 🔍 Мониторинг процесса

В Deploy Logs Railway ищите эмодзи сообщения:
- 🚀 Запуск n8n
- 📦 Загрузка ZIP архива
- 📂 Распаковка архива
- 🗄️ Поиск database.sqlite
- ✅ Успешная замена базы
- 🔄 Перезапуск n8n

## 🎯 Ожидаемая производительность

- **0-30 секунд**: n8n доступен (пустая база)
- **5-10 минут**: Загрузка ZIP архива (150MB)
- **1-2 минуты**: Распаковка и перезапуск
- **Итого**: ~7-12 минут до полного восстановления

## 🐛 Troubleshooting

### Проблемы с правами доступа
- Используется `/home/node/data` вместо `/data`
- Полные права пользователя node

### Проблемы с архивом
- Минимальный размер ZIP: 10MB
- Автоматический поиск database.sqlite
- Проверка размера распакованной базы (>50MB)

## 🔗 Альтернативные хостинги

Смотрите `DATABASE-HOSTING.md` для других вариантов размещения базы данных.

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