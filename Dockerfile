# Базовый образ n8n
FROM n8nio/n8n:1.45.1

# Установка curl (если используешь в init.sh)
USER root
RUN apk add --no-cache curl

# Копируем init.sh внутрь контейнера
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Указываем, что при запуске контейнера нужно запустить init.sh
ENTRYPOINT ["/bin/sh", "/init.sh"]

