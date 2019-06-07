#!/usr/bin/env bash

set -ex

sudo apt-get update
sudo apt-get install docker.io kubelet kubeadm kubectl
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo kubeadm init \
	--pod-network-cidr=192.168.1.0/24 \
	--apiserver-cert-extra-sans=k8s.azof.fr | tee kubeadm.init.log
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
sudo sysctl net.bridge.bridge-nf-call-iptables=1
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl get nodes

# allows master node to run containers (tainted)
kubectl taint nodes --all node-role.kubernetes.io/master-

# allows downloading from local repo
docker login k8s.azof.fr