#!/bin/bash

# Install required packages
apk add --no-cache \
    curl \
    openssh \
    docker \
    docker-compose \
    helm \
    kubectl

# Start Docker
systemctl enable docker
systemctl start docker

# Install K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create K3d cluster
k3d cluster create gitlab-cluster \
    -p "8080:80@loadbalancer" \
    -p "8443:443@loadbalancer" \
    --agents 2

# Create namespaces
kubectl create namespace gitlab
kubectl create namespace argocd

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Install GitLab using Helm
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.externalIP=192.168.56.110 \
  --set certmanager-issuer.email=lkolchi99@gmail.com

#   > Why these steps?
# > - We need Docker for running containers
# > - Helm is used for package management in Kubernetes
# > - K3d creates a local Kubernetes cluster
# > - GitLab is installed via Helm charts for easier management