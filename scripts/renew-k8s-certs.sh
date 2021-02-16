#!/usr/bin/env bash

set -ex

sudo kubeadm alpha certs renew all
sudo cat /etc/kubernetes/admin.conf > ~/.kube/config
cat ~/.kube/config