#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

# Update package list
apt-get update
check_status "Package list update"

# Install basic dependencies
apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    gnupg \
    lsb-release
check_status "Basic dependencies installation"

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh
usermod -aG docker vagrant
systemctl enable docker
systemctl start docker
check_status "Docker installation"

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
check_status "kubectl installation"

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
check_status "k3d installation"

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
check_status "Helm installation"

# Create k3d cluster
k3d cluster create iot-mel-hada \
    --api-port 6443 \
    --port "8888:80@loadbalancer" \
    --port "9000:9000@loadbalancer" \
    --agents 2
check_status "Cluster creation"

# Configure kubectl
mkdir -p /home/vagrant/.kube
k3d kubeconfig get iot-mel-hada > /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

# Create namespaces
kubectl create namespace gitlab
kubectl create namespace argocd
kubectl create namespace dev
check_status "Namespace creation"

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update
check_status "Helm repository configuration"

echo -e "\n${GREEN}Setup completed successfully!${NC}"