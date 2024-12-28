#!/bin/bash

echo "Starting cleanup process..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Clean up GitLab resources if they exist
if command_exists kubectl; then
    echo "Cleaning up GitLab resources..."
    
    # Check if gitlab namespace exists
    if kubectl get namespace gitlab >/dev/null 2>&1; then
        echo "Removing GitLab Helm release..."
        if command_exists helm; then
            helm uninstall gitlab -n gitlab || echo "GitLab helm release already removed"
        fi
        
        echo "Waiting for GitLab pods to terminate..."
        kubectl delete namespace gitlab --timeout=300s || echo "GitLab namespace already removed"
    else
        echo "GitLab namespace not found, skipping..."
    fi
fi

# Delete k3d cluster if it exists
if command_exists k3d; then
    echo "Checking for existing k3d clusters..."
    if k3d cluster list | grep -q "gitlab-cluster"; then
        echo "Deleting k3d cluster..."
        k3d cluster delete gitlab-cluster || handle_error "Failed to delete k3d cluster"
    else
        echo "No gitlab-cluster found, skipping..."
    fi
fi

# Clean up persistent volumes directory
echo "Cleaning up persistent volumes..."
sudo rm -rf /tmp/k3dvol/* || echo "No persistent volumes to clean"

# Remove helm repo if exists
if command_exists helm; then
    echo "Removing GitLab helm repository..."
    helm repo remove gitlab || echo "GitLab helm repo already removed"
fi

# Optional: Clean Docker images and volumes (commented out for safety)
# echo "Cleaning up Docker resources..."
# docker system prune -af  # This will remove all unused containers, networks, images
# docker volume prune -f   # This will remove all unused volumes

echo "Cleanup completed successfully!"
echo "Note: If you want to also remove Docker images and volumes, uncomment the last section of the script."