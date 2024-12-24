#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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
check_status "GitLab installation"

# Wait for GitLab pods to be ready
echo "Waiting for GitLab pods to be ready..."
kubectl wait --for=condition=ready pods --all -n gitlab --timeout=600s
check_status "GitLab pods ready"

echo -e "\n${GREEN}Deployment complete!${NC}"
echo "----------------------------------------"
echo "GitLab URL: http://gitlab.localhost:8888"
echo "GitLab credentials:"
echo "Username: root"
echo "Password: gitlab123!"
echo "----------------------------------------"

