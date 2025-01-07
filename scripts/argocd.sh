#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Print functions
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Clean up existing processes and resources
cleanup() {
    info "Cleaning up..."
    pkill -f "kubectl port-forward"
    kubectl delete ns argocd --ignore-not-found=true
    sleep 5
}

# Install ArgoCD
install_argocd() {
    info "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd
    
    # Apply ArgoCD installation manifest
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    info "Waiting for ArgoCD pods to be ready..."
    sleep 10
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
}

# Create ArgoCD
Create_argocd() {
# Create Application
kubectl apply -f ../confs/argocd.yaml -n argocd
}


# Setup port forwarding
setup_port_forward() {
    info "Setting up port forwarding..."
    kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server
    kubectl port-forward svc/argocd-server -n argocd 8888:443 &
    sleep 5
}

# Main execution
main() {
    # Clean up first
    cleanup

    # Install ArgoCD
    install_argocd

    # Create ArgoCD
    Create_argocd

    # Setup port forwarding
    setup_port_forward

    # Get login credentials
    PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

    success "Setup completed!"
    echo -e "\nArgoCD UI: https://localhost:8888"
    echo "Username: admin"
    echo "Password: $PASSWORD"
    
    # Show status
    echo -e "\nArgoCD pods status:"
    kubectl get pods -n argocd
}

# Run main
main