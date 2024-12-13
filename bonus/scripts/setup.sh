#!/bin/bash

# Create gitlab namespace
kubectl create namespace gitlab

# Add GitLab Helm repository
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Install GitLab with minimal configuration
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.externalIP=192.168.56.110 \
  --set certmanager.install=false \
  --set nginx-ingress.enabled=false \
  --set global.initialRootPassword=gitlabadmin \
  --timeout 600s

# Wait for GitLab to be ready
kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=600s

echo "GitLab is accessible at: http://192.168.56.110:8080"
echo "Default username: root"
echo "Default password: gitlabadmin"