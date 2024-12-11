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
        if [ "$2" = "critical" ]; then
            echo -e "${RED}Critical check failed. Please fix this before continuing.${NC}"
            exit 1
        fi
    fi
}

# Part 1: Basic Infrastructure Check
print_section "Part 1: Infrastructure Verification"

# Check VM Status
echo "Checking VM status..."
vagrant status | grep "running" > /dev/null
check_status "VM is running" "critical"

# Check System Resources
print_section "System Resources"
echo "Checking system resources..."
total_memory=$(free -m | awk '/^Mem:/{print $2}')
cpu_count=$(nproc)

if [ $total_memory -ge 5800 ]; then
    echo -e "${GREEN}✓ Memory OK ($total_memory MB)${NC}"
else
    echo -e "${RED}✗ Insufficient memory ($total_memory MB)${NC}"
fi

if [ $cpu_count -ge 2 ]; then
    echo -e "${GREEN}✓ CPU count OK ($cpu_count cores)${NC}"
else
    echo -e "${RED}✗ Insufficient CPU cores ($cpu_count cores)${NC}"
fi

# Check K3d Cluster
print_section "K3d Cluster Status"
echo "Checking K3d cluster..."
k3d cluster list | grep "gitlab-cluster" > /dev/null
check_status "K3d cluster exists"

# Check Kubernetes Nodes
print_section "Kubernetes Nodes"
echo "Checking Kubernetes nodes..."
node_count=$(kubectl get nodes | grep -c "Ready")
if [ $node_count -eq 3 ]; then
    echo -e "${GREEN}✓ All nodes ready ($node_count nodes)${NC}"
else
    echo -e "${RED}✗ Not all nodes ready (found $node_count, expected 3)${NC}"
fi

# Check Required Namespaces
print_section "Kubernetes Namespaces"
echo "Checking namespaces..."
for ns in gitlab argocd dev; do
    kubectl get namespace $ns > /dev/null 2>&1
    check_status "Namespace $ns exists"
done

# Check GitLab Pods
print_section "GitLab Components"
echo "Checking GitLab pods..."
kubectl get pods -n gitlab | grep "Running" > /dev/null
check_status "GitLab pods are running"

# Check GitLab Services
echo "Checking GitLab services..."
kubectl get svc -n gitlab gitlab-webservice > /dev/null 2>&1
check_status "GitLab webservice exists"

# Check Storage
print_section "Storage Status"
echo "Checking persistent volumes..."
pv_count=$(kubectl get pv | grep -c "Bound")
if [ $pv_count -gt 0 ]; then
    echo -e "${GREEN}✓ Found $pv_count bound persistent volumes${NC}"
else
    echo -e "${RED}✗ No bound persistent volumes found${NC}"
fi

# Check Web Access
print_section "Web Access"
echo "Checking GitLab web access..."
curl -s -o /dev/null -w "%{http_code}" http://192.168.56.110:8080 | grep "200\|302" > /dev/null
check_status "GitLab web interface is accessible"

# Check for Critical Errors
print_section "Error Check"
echo "Checking for critical errors in logs..."
error_count=$(kubectl logs -n gitlab --tail=100 $(kubectl get pods -n gitlab | grep webservice | awk '{print $1}') 2>/dev/null | grep -ic "error")
if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}✓ No recent errors in GitLab logs${NC}"
else
    echo -e "${YELLOW}! Found $error_count recent error messages in logs${NC}"
fi

# Final Summary
print_section "Setup Verification Summary"
echo "Basic Infrastructure: $(if [ $node_count -eq 3 ]; then echo -e "${GREEN}OK${NC}"; else echo -e "${RED}CHECK REQUIRED${NC}"; fi)"
echo "GitLab Status: $(if kubectl get pods -n gitlab | grep -q "Running"; then echo -e "${GREEN}OK${NC}"; else echo -e "${RED}CHECK REQUIRED${NC}"; fi)"
echo "Storage Status: $(if [ $pv_count -gt 0 ]; then echo -e "${GREEN}OK${NC}"; else echo -e "${RED}CHECK REQUIRED${NC}"; fi)"

# Print Important Information
print_section "Access Information"
echo "GitLab URL: http://192.168.56.110:8080"
echo "GitLab Root Password: gitlabadmin"

print_section "Next Steps"
echo "1. Access GitLab at http://192.168.56.110:8080"
echo "2. Login with root/gitlabadmin"
echo "3. Verify GitLab is working properly" 