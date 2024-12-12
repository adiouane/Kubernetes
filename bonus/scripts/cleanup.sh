#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
    fi
}

print_section "Starting Cleanup Process"

# Delete the k3d cluster
echo "Deleting k3d cluster..."
k3d cluster delete gitlab-cluster
check_status "K3d cluster deleted"

# Remove Helm repositories
echo "Removing Helm repositories..."
helm repo remove gitlab
check_status "GitLab Helm repository removed"

# Clean up Docker
echo "Cleaning up Docker resources..."
docker system prune -f
check_status "Docker cleanup completed"

# Remove created directories and files
print_section "Cleaning up files"

# Remove kubeconfig
echo "Removing kubeconfig..."
rm -f ~/.kube/config
check_status "Kubeconfig removed"

# Remove GitLab configuration
echo "Removing GitLab configuration..."
rm -f /vagrant/confs/gitlab-values.yaml
check_status "GitLab configuration removed"

# Stop and remove Vagrant VM
print_section "Stopping Vagrant VM"
echo "Stopping and removing Vagrant VM..."
vagrant destroy -f
check_status "Vagrant VM destroyed"

print_section "Cleanup Complete"
echo -e "${GREEN}All GitLab setup components have been removed.${NC}"
echo -e "${YELLOW}Note: To start fresh, run vagrant up again.${NC}" 