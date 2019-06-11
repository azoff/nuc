#!/usr/bin/env bash

set -ex

CERTHOST="${1:-azof.fr}"
CERTDIR="${2:-nginx/certs}"

ssh -t "nuc.$CERTHOST" \
	"sudo cp -vf /etc/letsencrypt/live/$CERTHOST/fullchain.pem /tmp/$CERTHOST.crt && \
	sudo cp -vf /etc/letsencrypt/live/$CERTHOST/privkey.pem /tmp/$CERTHOST.key && \
	sudo chown -v azoff /tmp/$CERTHOST.*"
scp "nuc.$CERTHOST:/tmp/$CERTHOST.*" $CERTDIR
ssh -t "nuc.$CERTHOST" "rm -fv /tmp/$CERTHOST.*"
