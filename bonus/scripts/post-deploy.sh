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

# Wait for GitLab to be ready
echo "Waiting for GitLab to be accessible..."
until curl -s --head --fail http://gitlab.localhost:8888 &>/dev/null; do
    echo "Waiting for GitLab to be accessible..."
    sleep 10
done
check_status "GitLab is accessible"

# Get GitLab root token
echo "Creating GitLab access token..."
TOKEN_RESPONSE=$(curl -s --request POST "http://gitlab.localhost:8888/oauth/token" \
  --header "Content-Type: application/json" \
  --data "{
    \"grant_type\": \"password\",
    \"username\": \"root\",
    \"password\": \"gitlab123!\"
  }")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
check_status "Access token created"

# Create new project
echo "Creating GitLab project..."
PROJECT_RESPONSE=$(curl -s --request POST "http://gitlab.localhost:8888/api/v4/projects" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"iot-project\",
    \"visibility\": \"public\"
  }")
check_status "Project created"

# Get project ID
PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.id')

# Configure Kubernetes integration
echo "Configuring Kubernetes integration..."
KUBE_TOKEN=$(kubectl -n gitlab get secret $(kubectl -n gitlab get serviceaccount gitlab-admin -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode)

curl -s --request POST "http://gitlab.localhost:8888/api/v4/projects/${PROJECT_ID}/clusters" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"k3d-cluster\",
    \"platform_kubernetes_attributes\": {
      \"api_url\": \"https://kubernetes.default.svc\",
      \"token\": \"${KUBE_TOKEN}\",
      \"namespace\": \"gitlab\"
    }
  }"
check_status "Kubernetes integration configured"

# Clone and push Part 3 configuration
echo "Migrating Part 3 configuration..."
git clone https://github.com/yourusername/iot-p3-project.git /tmp/iot-p3
cd /tmp/iot-p3
git remote add gitlab http://gitlab.localhost:8888/root/iot-project.git
git push -u gitlab master
check_status "Configuration migrated"

# Update ArgoCD configuration to use GitLab
echo "Updating ArgoCD configuration..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-project
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'http://gitlab.localhost:8888/root/iot-project.git'
    targetRevision: HEAD
    path: confs
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
check_status "ArgoCD configuration updated"

echo -e "\n${GREEN}Post-deployment setup completed!${NC}"
echo "----------------------------------------"
echo "Next steps:"
echo "1. Access GitLab at http://gitlab.localhost:8888"
echo "2. Login with root / gitlab123!"
echo "3. Check your project at http://gitlab.localhost:8888/root/iot-project"
echo "4. Verify ArgoCD is syncing from GitLab repository"
echo "----------------------------------------" 