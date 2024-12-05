#!/bin/bash

echo "Running troubleshooting checks..."

# Check system resources
echo "Checking system resources..."
free -h
df -h
nproc

# Check VirtualBox network
echo "Checking VirtualBox network..."
VBoxManage list hostonlyifs

# Check Docker status
echo "Checking Docker status..."
docker info || echo "Docker is not running!"

# Check k3d cluster
echo "Checking k3d cluster..."
k3d cluster list

# Check kubectl connection
echo "Checking kubectl connection..."
kubectl cluster-info

# Check GitLab pods
echo "Checking GitLab pods..."
kubectl get pods -n gitlab
kubectl get pods -n gitlab-runner 2>/dev/null

# Check Argo CD pods
echo "Checking Argo CD pods..."
kubectl get pods -n argocd

# Check services
echo "Checking services..."
kubectl get svc -A

# Check persistent volumes
echo "Checking persistent volumes..."
kubectl get pv,pvc -A

# Check GitLab specific resources
echo "Checking GitLab specific resources..."
kubectl get ingress -n gitlab
kubectl get secrets -n gitlab | grep gitlab
kubectl get configmap -n gitlab | grep gitlab

# Check GitLab Runner status
echo "Checking GitLab Runner status..."
kubectl get serviceaccount -n gitlab-runner
kubectl get rolebinding -n gitlab-runner

# Check node resources
echo "Checking node resources..."
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"