#!/usr/bin/env bash

kubectl --kubeconfig ~/.kube/nuc.config \
	create secret generic nuc \
		--from-file=cloudflare=.secrets/cloudflare.ini