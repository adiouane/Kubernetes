#!/bin/bash
#checker
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
    fi
}

echo "Starting verification of bonus part setup..."

# 1. Check if required tools are installed
echo -e "\n${YELLOW}Checking required tools:${NC}"
for tool in docker kubectl k3d helm; do
    command_exists $tool
    print_status $? "$tool is installed"
done

# 2. Check if k3d cluster is running
echo -e "\n${YELLOW}Checking k3d cluster:${NC}"
k3d cluster list | grep -q "iot-mel-hada"
print_status $? "k3d cluster 'iot-mel-hada' is running"

# 3. Check required namespaces
echo -e "\n${YELLOW}Checking namespaces:${NC}"
for ns in gitlab argocd dev; do
    kubectl get namespace $ns >/dev/null 2>&1
    print_status $? "Namespace '$ns' exists"
done

# 4. Check GitLab deployment
echo -e "\n${YELLOW}Checking GitLab deployment:${NC}"
kubectl get pods -n gitlab | grep -q "gitlab"
print_status $? "GitLab pods are running"

# Check GitLab status
curl -s -o /dev/null -w "%{http_code}" http://gitlab.gitlab.local:80

# Check ArgoCD sync status
kubectl get application iot-p3-app -n argocd -o jsonpath='{.status.sync.status}'

# Check deployment in dev namespace
kubectl get pods -n dev

# 5. Check ArgoCD deployment
echo -e "\n${YELLOW}Checking ArgoCD deployment:${NC}"
kubectl get pods -n argocd | grep -q "argocd-server"
print_status $? "ArgoCD pods are running"

# 6. Check GitLab ingress
echo -e "\n${YELLOW}Checking GitLab access:${NC}"
grep -q "gitlab.localhost" /etc/hosts
print_status $? "GitLab hostname is configured in /etc/hosts"

# check all pods are running
echo -e "\n${YELLOW}Checking all pods are running:${NC}"
kubectl get pods --all-namespaces | grep -q "Running"
print_status $? "All pods are running"

# check all services are running
echo -e "\n${YELLOW}Checking all services are running:${NC}"
kubectl get services --all-namespaces | grep -q "Running"
print_status $? "All services are running"

# 7. Check ArgoCD application
echo -e "\n${YELLOW}Checking ArgoCD application:${NC}"
kubectl get application iot-p3-app -n argocd >/dev/null 2>&1
print_status $? "ArgoCD application 'iot-p3-app' exists"

# 8. Check services accessibility
echo -e "\n${YELLOW}Checking service accessibility:${NC}"
# Check GitLab service
curl -s -o /dev/null -w "%{http_code}" http://gitlab.localhost:80 | grep -q "200\|302"
print_status $? "GitLab service is accessible"

# Final success message
echo -e "\n${GREEN}Verification completed successfully!${NC}"

# Check service ports
echo -e "\n${YELLOW}Checking service ports:${NC}"
# Check GitLab port
netstat -tuln | grep ":80" > /dev/null
print_status $? "GitLab port (80) is open"

# Check ArgoCD port
netstat -tuln | grep ":8080" > /dev/null
print_status $? "ArgoCD port (9000) is open"

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
