FROM n8nio/n8n

# Копируем init.sh внутрь образа
COPY init.sh /app/init.sh

# Указываем bash напрямую — не нужны права на выполнение
CMD ["bash", "/app/init.sh"]

