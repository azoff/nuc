#!/usr/bin/env bash

set -ex

HOST=${1:-azof.fr}
EMAIL=${2:-jon@$HOST}
CHALLENGE=${3:-dns}

sudo apt-get update
sudo apt-get install certbot letsencrypt
sudo certbot certonly --manual --preferred-challenge=$CHALLENGE \
	--server=https://acme-v02.api.letsencrypt.org/directory \
	--agree-tos \
	--email=$EMAIL \
	-d *.$HOST