#!/bin/bash
#cleanup script
echo "Starting complete cleanup..."

# 1. Remove GitLab cluster and k3d resources
echo "Removing k3d cluster and resources..."
k3d cluster delete gitlab-cluster 2>/dev/null || true

# 2. Remove installed binaries
echo "Removing installed binaries..."
sudo rm -rf /usr/local/bin/kubectl
sudo rm -rf /usr/local/bin/helm
sudo rm -rf /usr/local/bin/k3d

# 3. Remove Docker resources
echo "Removing Docker resources..."
# Stop and remove containers
docker ps -a | grep -E 'k3d|gitlab|argocd' | awk '{print $1}' | xargs -r docker rm -f
# Remove volumes
docker volume ls -q | grep -E 'k3d|gitlab|argocd' | xargs -r docker volume rm -f
# Remove networks
docker network ls | grep -E 'k3d|gitlab|argocd' | awk '{print $1}' | xargs -r docker network rm

# 4. Remove configuration files
echo "Removing configuration files..."
sudo rm -rf ~/.kube/config
sudo rm -rf ~/.k3d
sudo rm -rf ~/.local/share/k3d
sudo rm -f gitlab-values.yaml

# 5. Remove GitLab storage
echo "Removing GitLab storage..."
sudo rm -rf /var/lib/rancher/k3s/storage/gitlab*
sudo rm -rf /opt/gitlab*
sudo rm -rf /var/opt/gitlab*
sudo rm -rf /var/lib/docker/volumes/*gitlab*

# 6. Remove hosts entry
echo "Removing hosts entry..."
sudo sed -i '/gitlab.localhost/d' /etc/hosts

# 7. Clean Docker system
echo "Cleaning Docker system..."
docker system prune -f --volumes

# 8. Verify cleanup
echo -e "\nVerifying cleanup..."
echo "Docker containers:"
docker ps -a | grep -E 'k3d|gitlab|argocd' || echo "No related containers found"
echo -e "\nDocker volumes:"
docker volume ls | grep -E 'k3d|gitlab|argocd' || echo "No related volumes found"
echo -e "\nDocker networks:"
docker network ls | grep -E 'k3d|gitlab|argocd' || echo "No related networks found"

# Add user to docker group to avoid permission issues
sudo usermod -aG docker $USER

echo "Finding GitLab storage locations..."

# List all GitLab-related volumes
echo "GitLab Volumes:"
echo "--------------"
docker volume ls | grep -E 'gitaly|postgresql|redis|minio'

# Get detailed volume information
echo -e "\nVolume Locations:"
echo "----------------"
for volume in $(docker volume ls -q | grep -E 'gitaly|postgresql|redis|minio'); do
    echo "Volume: $volume"
    sudo ls -lah $(docker volume inspect $volume --format '{{ .Mountpoint }}')
    echo "Size:"
    sudo du -sh $(docker volume inspect $volume --format '{{ .Mountpoint }}')
    echo "---"
done

# Create cleanup function
cleanup_volumes() {
    echo "Cleaning up GitLab persistent volumes..."
    
    # Stop related containers first
    docker ps -a | grep -E 'gitaly|postgresql|redis|minio' | awk '{print $1}' | xargs -r docker stop
    
    # Remove volumes
    docker volume ls -q | grep -E 'gitaly|postgresql|redis|minio' | xargs -r docker volume rm -f
    
    echo "Volumes cleaned up!"
}

# Ask if user wants to clean up
read -p "Do you want to clean up these volumes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    cleanup_volumes
fi

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

echo -e "\nCleanup completed!"