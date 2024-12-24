#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC} $2"
    else
        echo -e "${RED}[✗]${NC} $2"
        exit 1
    fi
}

echo "Starting verification of bonus part setup..."

# 1. Check if required tools are installed
echo -e "\n${YELLOW}Checking required tools:${NC}"
for tool in docker kubectl k3d helm; do
    if command_exists $tool; then
        print_status 0 "$tool is installed"
    else
        print_status 1 "$tool is not installed"
    fi
done

# 2. Check if k3d cluster is running
echo -e "\n${YELLOW}Checking k3d cluster:${NC}"
if k3d cluster list | grep -q "iot-mel-hada"; then
    print_status 0 "k3d cluster 'iot-mel-hada' is running"
else
    print_status 1 "k3d cluster 'iot-mel-hada' is not running"
fi

# 3. Check required namespaces
echo -e "\n${YELLOW}Checking namespaces:${NC}"
for ns in gitlab argocd dev; do
    if kubectl get namespace $ns >/dev/null 2>&1; then
        print_status 0 "Namespace '$ns' exists"
    else
        print_status 1 "Namespace '$ns' does not exist"
    fi
done

# 4. Check GitLab deployment
echo -e "\n${YELLOW}Checking GitLab deployment:${NC}"
if kubectl get pods -n gitlab | grep -q "gitlab"; then
    print_status 0 "GitLab pods are running"
else
    print_status 1 "GitLab pods are not running"
fi

# 5. Check ArgoCD deployment
echo -e "\n${YELLOW}Checking ArgoCD deployment:${NC}"
if kubectl get pods -n argocd | grep -q "argocd-server"; then
    print_status 0 "ArgoCD pods are running"
else
    print_status 1 "ArgoCD pods are not running"
fi

# 6. Check GitLab ingress
# check ingr
echo -e "\n${YELLOW}Checking GitLab access:${NC}"
if grep -q "gitlab.localhost" /etc/hosts; then
    print_status 0 "GitLab hostname is configured in /etc/hosts"
else
    print_status 1 "GitLab hostname is not configured in /etc/hosts"
fi

# check all pods are running
echo -e "\n${YELLOW}Checking all pods are running:${NC}"
if kubectl get pods --all-namespaces | grep -q "Running"; then
    print_status 0 "All pods are running"
else
    print_status 1 "Some pods are not running"
fi

# check all services are running
echo -e "\n${YELLOW}Checking all services are running:${NC}"
if kubectl get services --all-namespaces | grep -q "Running"; then
    print_status 0 "All services are running"
else
    print_status 1 "Some services are not running"
fi

# 7. Check ArgoCD application
echo -e "\n${YELLOW}Checking ArgoCD application:${NC}"
if kubectl get application iot-p3-app -n argocd >/dev/null 2>&1; then
    print_status 0 "ArgoCD application 'iot-p3-app' exists"
else
    print_status 1 "ArgoCD application 'iot-p3-app' does not exist"
fi

# 8. Check services accessibility
echo -e "\n${YELLOW}Checking service accessibility:${NC}"
# Check GitLab service
if curl -s -o /dev/null -w "%{http_code}" http://gitlab.localhost:8888 | grep -q "200\|302"; then
    print_status 0 "GitLab service is accessible"
else
    print_status 1 "GitLab service is not accessible"
fi

# Final success message
echo -e "\n${GREEN}Verification completed successfully!${NC}"



# Check service ports
echo -e "\n${YELLOW}Checking service ports:${NC}"
# Check GitLab port
if netstat -tuln | grep ":8888" > /dev/null; then
    print_status 0 "GitLab port (8888) is open"
else
    print_status 1 "GitLab port (8888) is not open"
fi

# Check ArgoCD port
if netstat -tuln | grep ":9000" > /dev/null; then
    print_status 0 "ArgoCD port (9000) is open"
else
    print_status 1 "ArgoCD port (9000) is not open"
fi


echo "Checking ports and services..."

echo -e "\nServices:"
kubectl get svc -A | grep -E 'argocd|gitlab'

echo -e "\nIngresses:"
kubectl get ingress -A

echo -e "\nPort forwarding:"
sudo netstat -tulpn | grep -E '9000'

echo -e "\nPods:"
kubectl get pods -A | grep -E 'argocd|gitlab'

echo -e "\nEndpoints:"
kubectl get endpoints -A | grep -E 'argocd|gitlab'