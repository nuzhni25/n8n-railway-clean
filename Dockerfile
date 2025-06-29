# Базовый образ n8n
FROM n8nio/n8n:1.45.1

# Установка curl (если используешь в init.sh)
USER root
RUN apt-get update && apt-get install -y curl && apt-get clean

# Копируем init.sh внутрь контейнера
COPY init.sh /init.sh

# Указываем, что при запуске контейнера нужно запустить init.sh
ENTRYPOINT ["/bin/bash", "/init.sh"]

