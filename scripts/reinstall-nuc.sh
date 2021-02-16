#!/usr/bin/env bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TLD_NAME=azof.fr
SSH_HOST=nuc.$TLD_NAME
REGISTRY_HOST=k8s.$TLD_NAME
CERTBOT_VERSION=0.7.0
NGINX_VERSION=1.5.10
REGISTRY_VERSION=1.3.0
HMAD_VERSION=1.4.0
CLOUDFLARE_EMAIL=jon@azof.fr
HTPASSWD_USER=jon

if [[ $CLOUDFLARE_KEY == "" ]]; then
	echo "usage CLOUDFLARE_KEY=... $0"
	echo "see: https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials"
	exit 2
fi

if [[ $HTPASSWD_PASS == "" ]]; then
	echo "usage HTPASSWD_PASS=... $0"
	echo "see: https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials"
	exit 2
fi

if [[ ! -f $DIR/../../hmad/secrets.json ]]; then
	echo "please make sure that the hmad secrets.json file exists"
	echo "see: https://console.developers.google.com/iam-admin/serviceaccounts/details/101790955415745813661;edit=true?previousPage=%2Fapis%2Fcredentials%3Fproject%3Dhmad-224518&folder=&organizationId=&project=hmad-224518"
	echo "and: https://app.mailgun.com/app/sending/domains/mail.harrisonmetalu.mn/credentials"
	echo "and: https://dashboard.stripe.com/apikeys"
	exit 2
fi

ssh $SSH_HOST sudo kubeadm reset
ssh $SSH_HOST sudo kubeadm init --pod-network-cidr=192.168.1.0/24 --apiserver-cert-extra-sans=$REGISTRY_HOST

echo "> installing certbot image..."
docker save $REGISTRY_HOST/azoff/certbot:$CERTBOT_VERSION >| /tmp/certbot.$CERTBOT_VERSION.tar
scp /tmp/certbot.$CERTBOT_VERSION.tar $SSH_HOST:certbot.$CERTBOT_VERSION.tar
ssh $SSH_HOST docker load --input certbot.$CERTBOT_VERSION.tar
ssh $SSH_HOST rm -rvf certbot.$CERTBOT_VERSION.tar
rm -rvf /tmp/certbot.$CERTBOT_VERSION.tar

echo "> creating cloudflare secret..."
echo "dns_cloudflare_email = $CLOUDFLARE_EMAIL" >| /tmp/cloudflare.ini
echo "dns_cloudflare_api_key = $CLOUDFLARE_KEY" >> /tmp/cloudflare.ini

echo "> creating registry secrets..."
htpasswd -Bbc /tmp/registry.htpasswd $HTPASSWD_USER $HTPASSWD_PASS
md5 -qs registry > /tmp/registry.secret

echo "> creating nuc secret..."
kubectl create secret generic nuc \
	--from-file=/tmp/cloudflare.ini \
	--from-file=/tmp/registry.htpasswd \
	--from-file=/tmp/registry.secret
rm /tmp/cloudflare.ini
rm /tmp/registry.htpasswd
rm /tmp/registry.htpasswd

echo "> creating certbot volume..."
kubectl apply -f $DIR/../certbot/volume.yml

echo "> creating renewal cronjob..."
kubectl apply -f $DIR/../certbot/certrenew.yml
kubectl create job --from=cronjob/certrenew certrenew-manual # force check

echo "> installing nginx image..."
# NGINX_VERSION=1.5.5
# TLD_NAME=azof.fr
# SSH_HOST=nuc.$TLD_NAME
# REGISTRY_HOST=k8s.$TLD_NAME
# docker build -t $REGISTRY_HOST/azoff/nginx:$NGINX_VERSION .
docker save $REGISTRY_HOST/azoff/nginx:$NGINX_VERSION >| /tmp/nginx.$NGINX_VERSION.tar
scp /tmp/nginx.$NGINX_VERSION.tar $SSH_HOST:nginx.$NGINX_VERSION.tar
ssh $SSH_HOST docker load --input nginx.$NGINX_VERSION.tar
ssh $SSH_HOST rm -rvf nginx.$NGINX_VERSION.tar
rm -rvf /tmp/nginx.$NGINX_VERSION.tar

echo "> creating nginx deployment..."
kubectl apply -f $DIR/../nginx/deployment.yml

echo "> creating nginx service..."
kubectl apply -f $DIR/../nginx/service.yml

echo "> installing registry image..."
docker save $REGISTRY_HOST/azoff/registry:$REGISTRY_VERSION >| /tmp/registry.$REGISTRY_VERSION.tar
scp /tmp/registry.$REGISTRY_VERSION.tar $SSH_HOST:registry.$REGISTRY_VERSION.tar
ssh $SSH_HOST docker load --input registry.$REGISTRY_VERSION.tar
ssh $SSH_HOST rm -rvf registry.$REGISTRY_VERSION.tar
rm -rvf /tmp/registry.$REGISTRY_VERSION.tar

echo "> creating registry volume..."
kubectl apply -f $DIR/../registry/volume.yml

echo "> creating registry deployment..."
kubectl apply -f $DIR/../registry/deployment.yml

echo "> creating registry service..."
kubectl apply -f $DIR/../registry/service.yml

echo "> checking service"
sleep 5
docker login k8s.azof.fr

echo "> creating docker registry pull secret..."
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson

echo "> creating hmad namespace"
kubectl create namespace hmad

echo "> creating hmad secret"
kubectl -n hmad create secret generic hmad --from-file=$DIR/../../hmad/secrets.json

echo "> creating hmad deployment..."
kubectl -n hmad apply -f $DIR/../../hmad/deployment.yml

echo "> creating hmad service..."
kubectl -n hmad apply -f $DIR/../../hmad/service.yml
