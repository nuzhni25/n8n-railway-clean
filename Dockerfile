FROM n8nio/n8n:latest

# Копируем init.sh внутрь контейнера
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Запускаем скрипт при старте контейнера
CMD ["/bin/sh", "/init.sh"]

