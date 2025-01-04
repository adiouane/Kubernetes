#!/bin/bash
# ArgoCD-GitLab Integration Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Configuration
GITLAB_TOKEN="${GITLAB_TOKEN}"
# Use internal Kubernetes DNS name for GitLab
GITLAB_INTERNAL_URL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8181"
REPO_URL="$GITLAB_INTERNAL_URL/root/iot.git"

configure_argocd() {
    info "Installing ArgoCD..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD server to be ready
    info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
    
    # Create TLS secret for GitLab
    kubectl create secret generic gitlab-auth -n argocd \
        --from-literal=username=root \
        --from-literal=password=$GITLAB_TOKEN \
        --dry-run=client -o yaml | kubectl apply -f -

    # Update ArgoCD ConfigMap with GitLab configuration
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  repositories: |
    - url: $REPO_URL
      type: git
      insecure: true
      insecureIgnoreHostKey: true
      username: root
      passwordSecret:
        name: gitlab-auth
        key: password
EOF

    # Restart ArgoCD server to apply changes
    kubectl rollout restart deployment argocd-server -n argocd
    kubectl rollout status deployment argocd-server -n argocd
}

setup_port_forward() {
    info "Setting up port forwarding..."
    pkill -f "kubectl port-forward.*argocd" || true
    kubectl port-forward svc/argocd-server -n argocd 8888:443 &
    sleep 5
}

add_repository() {
    info "Adding GitLab repository to ArgoCD..."
    
    # Login to ArgoCD
    argocd login localhost:8888 --username admin --password $ARGOCD_PASSWORD --insecure
    
    # Add repository
    argocd repo add $REPO_URL \
        --username root \
        --password $GITLAB_TOKEN \
        --insecure-skip-server-verification \
        --upsert
}

main() {
    info "Starting ArgoCD-GitLab integration..."
    
    # Configure ArgoCD
    configure_argocd
    
    # Setup port forwarding
    setup_port_forward
    
    # Add repository
    add_repository

    
    
    success "Integration completed successfully!"
    echo -e "\nAccess URLs:"
    echo "GitLab: http://gitlab.localhost:8080 (external)"
    echo "ArgoCD: https://localhost:8888"
    echo -e "\nCredentials:"
    echo "GitLab - username: root, token: $GITLAB_TOKEN"
    echo "ArgoCD - username: admin, password: $ARGOCD_PASSWORD"
    
    # Display repository status
    echo -e "\nRepository Status:"
    argocd repo list
}

# Run the script
main
