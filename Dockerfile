FROM n8nio/n8n

COPY init.sh /init.sh

ENTRYPOINT ["/init.sh"]
