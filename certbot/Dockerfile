FROM certbot/dns-cloudflare

ARG CERT_HOST=azof.fr
ARG CERT_EMAIL=jon@$CERT_HOST
ARG CERT_KEY_SIZE=4096

ARG CERTBOT_CONFIG_DIR=/etc/certbot
ENV CERTBOT_CONFIG_DIR=$CERTBOT_CONFIG_DIR

ARG CLOUDFLARE_API_KEY
RUN touch /etc/cloudflare.ini && \
	echo "dns_cloudflare_email = $CERT_EMAIL" > /etc/cloudflare.ini && \
	echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" >> /etc/cloudflare.ini && \
	chmod 600 /etc/cloudflare.ini

RUN mkdir -p $CERTBOT_CONFIG_DIR && \
	wget "https://github.com/certbot/certbot/raw/master/certbot-nginx/certbot_nginx/tls_configs/options-ssl-nginx.conf" \
		-O "$CERTBOT_CONFIG_DIR/options-ssl-nginx.conf" && \
  	wget "https://github.com/certbot/certbot/raw/master/certbot/ssl-dhparams.pem" \
  		-O "$CERTBOT_CONFIG_DIR/ssl-dhparams.pem"

RUN certbot certonly \
		# --staging \
		--config-dir $CERTBOT_CONFIG_DIR \
	    --email $CERT_EMAIL \
	    --dns-cloudflare \
  		--dns-cloudflare-credentials /etc/cloudflare.ini \
		--non-interactive \
	    --rsa-key-size $CERT_KEY_SIZE \
	    --agree-tos \
	    -d *.$CERT_HOST || true

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["certbot --config-dir $CERTBOT_CONFIG_DIR renew"]