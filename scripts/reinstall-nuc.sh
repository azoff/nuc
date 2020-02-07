#!/usr/bin/env bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TLD_NAME=azof.fr
SSH_HOST=nuc.$TLD_NAME
REGISTRY_HOST=k8s.$TLD_NAME
CERTBOT_VERSION=0.7.0
NGINX_VERSION=1.5.5
REGISTRY_VERSION=1.3.0
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
htpasswd -bc /tmp/registry.htpasswd $HTPASSWD_USER $HTPASSWD_PASS
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
kubectl create secret generic dockerconfigjson \
    --from-file=.dockerconfigjson=$(echo ~/.docker/config.json) \
    --type=kubernetes.io/dockerconfigjson