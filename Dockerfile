FROM n8nio/n8n:1.45.1

USER root
RUN apk add --no-cache wget

COPY init.sh /init.sh
RUN chmod +x /init.sh

CMD ["/init.sh"]
