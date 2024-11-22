#!/bin/bash

sudo kill $( lsof -i:6443 -t )
/usr/local/bin/k3s-uninstall.sh

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --node-ip 192.168.56.110 --bind-address=192.168.56.110" sh -s -
sleep 20
kubectl apply -f /vagrant/confs/deployments.yaml
kubectl apply -f /vagrant/confs/services.yaml
kubectl apply -f /vagrant/confs/ingress.yaml
sleep 20
kubectl get all