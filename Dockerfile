# Базовый образ n8n slim
FROM n8nio/n8n:1.45.1-slim

# Установка curl
RUN apt-get update && apt-get install -y curl && apt-get clean

# Копируем init.sh
COPY init.sh /init.sh

# Указываем запуск скрипта на старте
ENTRYPOINT ["/bin/sh", "/init.sh"]
CMD ["n8n"]

