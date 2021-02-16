FROM nginx:alpine

ARG SSL_CONFIG_DIR=/etc/nginx/ssl
RUN mkdir -p $SSL_CONFIG_DIR && \
	wget "https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf" \
		-O "$SSL_CONFIG_DIR/options-ssl-nginx.conf" && \
  	wget "https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem" \
  		-O "$SSL_CONFIG_DIR/ssl-dhparams.pem"

ADD ./static /usr/share/nginx/html
ADD ./conf.d /etc/nginx/conf.d

ADD ./scripts/entrypoint /bin/entrypoint
ADD ./scripts/nginx-reload /etc/periodic/daily/nginx-reload
ADD ./scripts/cron-pulse /etc/periodic/15min/cron-pulse

ENTRYPOINT ["/bin/entrypoint"]
CMD ["nginx", "-g", "daemon off;"]

EXPOSE 80 443