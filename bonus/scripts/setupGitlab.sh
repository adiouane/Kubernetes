#!/bin/bash
# Inception of Things - Bonus Part (Storage Optimized)
# Author: adiouane
# Date: 2025-01-03

# Set error handling
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Clean up function
cleanup() {
    info "Cleaning up old containers and images..."
    docker system prune -af
    docker volume prune -f
}

# Install dependencies
install_dependencies() {
    info "Installing minimal required dependencies..."
    
    sudo apt-get update -y
    
    # Install Docker if needed
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi

    # Install k3d
    if ! command -v k3d &> /dev/null; then
        wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi

    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/kubectl
    fi

    # Install Helm
    if ! command -v helm &> /dev/null; then
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    fi

    cleanup
}

# Setup K3d cluster with minimal resources
setup_cluster() {
    info "Setting up minimal K3d cluster..."

    # Delete existing cluster if present
    k3d cluster delete gitlab-cluster 2>/dev/null || true

    # Create minimal cluster with optimized resources
    k3d cluster create gitlab-cluster \
        --servers 1 \
        --agents 1 \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer"
        # --k3s-arg '--disable=traefik@server:*' \
        # --k3s-arg '--disable=metrics-server@server:*' 
    # Wait for cluster to be ready
    info "Waiting for cluster to be ready..."
    until kubectl get nodes | grep -q " Ready"; do
        info "Waiting for nodes to be ready..."
        sleep 5
    done

    # Create namespaces
    kubectl create namespace gitlab
    kubectl create namespace argocd
    kubectl create namespace dev

    info "Cluster setup completed"
}



create_gitlab_config() {
    cat <<EOF > gitlab-values.yaml
global:
  hosts:
    domain: localhost
    https: false
    gitlab:
      name: gitlab.localhost
      https: false
    externalUrl: http://gitlab.localhost:8080
  ingress:
    configureCertmanager: false
    class: nginx
    enabled: true
    tls:
      enabled: false

certmanager:
  install: false

nginx-ingress:
  enabled: false

gitlab-runner:
  install: false

prometheus:
  install: false


gitlab:
  webservice:
    ingress:
      enabled: true
      hosts:
        - gitlab.localhost

EOF
}



deploy_applications() {
    info "Deploying applications..."

    # Update hosts file
    sudo sed -i '/gitlab.localhost/d' /etc/hosts
    sudo sed -i '/minio.localhost/d' /etc/hosts
    sudo sed -i '/registry.localhost/d' /etc/hosts
    sudo sed -i '/kas.localhost/d' /etc/hosts
    echo "127.0.0.1 gitlab.localhost minio.localhost registry.localhost kas.localhost" | sudo tee -a /etc/hosts
    

    # Install GitLab
    info "Adding GitLab Helm repository..."
    helm repo add gitlab https://charts.gitlab.io/
    helm repo update

    # Uninstall previous GitLab if exists
    helm uninstall gitlab -n gitlab 2>/dev/null || true
    kubectl delete pvc --all -n gitlab 2>/dev/null || true
    sleep 10

    info "Installing GitLab..."
    helm upgrade --install gitlab gitlab/gitlab \
        --namespace gitlab \
        --timeout 600s \
        --values gitlab-values.yaml \
        --wait



    # Wait for services to be ready
    info "Waiting for services to be ready..."
    kubectl wait --namespace gitlab --for=condition=ready pod -l app=webservice --timeout=600s || true

    #expose gitlab to outside
    sudo kubectl port-forward services/gitlab-webservice-default 80:8181 -n gitlab --address="0.0.0.0"

    # Get access credentials
    info "Retrieving access credentials..."
    echo -e "\n${GREEN}=== Access Information ===${NC}"
    echo -e "GitLab URL: http://gitlab.localhost:8080"
    echo -e "GitLab Username: root"
    
    # Get GitLab root password
    GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode)
    echo -e "GitLab Password: $GITLAB_PASSWORD"
    
    
    # Print status
    echo -e "\n${BLUE}=== Pod Status ===${NC}"
    sudo kubectl get pods -n gitlab
    echo -e "\n${BLUE}=== Ingress Status ===${NC}"
    sudo kubectl get ingress -A
}

verify_services() {
    info "Verifying services accessibility..."
    
    # Wait for GitLab webservice to be ready
    for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://gitlab.localhost:8080/users/sign_in | grep -q "200\|302"; then
            success "GitLab is accessible"
            break
        fi
        info "Waiting for GitLab to be accessible... (attempt $i/30)"
        sleep 10
    done
    
}

main() {
    info "Starting IoT Bonus Setup (Storage Optimized)"
    
    # Check available disk space
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        error "Not enough disk space. At least 10GB required. Available: ${AVAILABLE_SPACE}GB"
        exit 1
    fi

    cleanup
    install_dependencies
    setup_cluster
    # create_ingress_config
    # setup_ingress
    create_gitlab_config
    deploy_applications
    verify_services
    echo "gitlab-webservice-default.gitlab.svc.cluster.local"
    success "Setup completed! Please wait a few minutes for all services to start."
    info "Note: If services are not immediately accessible, wait 5-10 minutes for full initialization."
}

main
