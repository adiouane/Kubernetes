#!/bin/bash

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode=644 --node-ip 192.168.56.110 --bind-address=192.168.56.110" sh -s -
sleep 15
cp /var/lib/rancher/k3s/server/node-token /vagrant/