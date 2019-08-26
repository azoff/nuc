FROM certbot/dns-cloudflare

ARG CLOUDFLARE_EMAIL=jon@azof.fr
ARG CLOUDFLARE_API_KEY
RUN touch /etc/cloudflare.ini && \
	echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" > /etc/cloudflare.ini && \
	echo "dns_cloudflare_api_key = $CLOUDFLARE_API_KEY" >> /etc/cloudflare.ini && \
	chmod 600 /etc/cloudflare.ini

ENTRYPOINT ["certbot"]