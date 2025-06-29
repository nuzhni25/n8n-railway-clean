FROM n8nio/n8n

# Копируем init.sh внутрь
COPY init.sh /init.sh

# Устанавливаем права на выполнение
RUN chmod +x /init.sh

# Запускаем через bash — это надёжно
CMD ["bash", "/app/init.sh"]

