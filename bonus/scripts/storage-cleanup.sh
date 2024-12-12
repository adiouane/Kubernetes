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

print_section "Starting Storage Cleanup"

# Delete all PVCs in gitlab namespace
echo "Deleting Persistent Volume Claims..."
kubectl delete pvc --all -n gitlab
check_status "PVCs deleted"

# Delete all PVs
echo "Deleting Persistent Volumes..."
kubectl delete pv --all
check_status "PVs deleted"

# Clean up local storage
echo "Cleaning up local storage..."
sudo rm -rf /var/lib/rancher/k3s/storage/*
check_status "Local storage cleaned"

# Clean up Docker volumes
echo "Cleaning up Docker volumes..."
docker volume prune -f
check_status "Docker volumes cleaned"

# Remove any leftover storage directories
echo "Cleaning up any leftover storage directories..."
sudo rm -rf /var/lib/docker/volumes/*
check_status "Leftover storage cleaned"

print_section "Storage Cleanup Complete"
echo -e "${GREEN}All storage has been cleaned up.${NC}"
echo -e "${YELLOW}Note: You may need to restart your cluster for changes to take effect.${NC}" 