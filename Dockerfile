FROM n8nio/n8n

# Устанавливаем переменную для правильных прав доступа к Volume
ENV RAILWAY_RUN_UID=0

# Устанавливаем su-exec для переключения пользователей
USER root
RUN apk add --no-cache su-exec

# Копируем и делаем исполняемым init-скрипт
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Создаём директорию для данных
RUN mkdir -p /data

# Указываем рабочую директорию
WORKDIR /home/node

# Запускаем через init-скрипт
ENTRYPOINT ["/init.sh"]
CMD ["n8n"] 