FROM certbot/dns-cloudflare

ARG CLOUDFLARE_INI_PATH=/etc/cloudflare.ini
ENV CLOUDFLARE_INI_PATH=$CLOUDFLARE_INI_PATH

CMD ["certbot", "renew"]