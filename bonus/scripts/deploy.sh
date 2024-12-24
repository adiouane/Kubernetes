#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install GitLab using Helm
echo "Installing GitLab..."
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --namespace gitlab \
  --set global.hosts.domain=localhost \
  --set global.hosts.externalIP=192.168.56.110 \
  --set global.hosts.gitlab.name=gitlab.localhost \
  --set certmanager-issuer.email=me@example.com \
  --set global.appConfig.gitlab_rails.initial_root_password=gitlab123!

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pods --all -n argocd --timeout=300s

# Configure ArgoCD
kubectl apply -f /vagrant/confs/argocd.yaml

echo -e "\n${GREEN}Deployment complete!${NC}"
echo "----------------------------------------"
echo "GitLab URL: http://gitlab.localhost:8888"
echo "ArgoCD URL: http://192.168.56.110:9000"
echo "GitLab credentials:"
echo "Username: root"
echo "Password: gitlab123!"
echo "----------------------------------------"

