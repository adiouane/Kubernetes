#!/bin/bash

# Clean up existing installation
echo "Cleaning up existing installation..."
helm uninstall gitlab -n gitlab || true
kubectl delete namespace gitlab || true
kubectl delete clusterrolebinding gitlab-prometheus-server || true

# Wait for namespace deletion to complete
echo "Waiting for cleanup to complete..."
kubectl wait --for=delete namespace/gitlab --timeout=300s || true

# Create new namespace
echo "Creating gitlab namespace..."
kubectl create namespace gitlab

# Add GitLab Helm repository
echo "Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Install GitLab with minimal configuration
echo "Installing GitLab..."
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.externalIP=192.168.56.110 \
  --set certmanager.install=false \
  --set nginx-ingress.enabled=false \
  # --set global.initialRootPassword=gitlabadmin \
  --set prometheus.install=false \
  --timeout 600s

# Wait for GitLab webservice to be ready
echo "Waiting for GitLab to be ready..."
kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=600s || true

echo "GitLab is accessible at: http://192.168.56.110:8080"
echo "Default username: root"
echo "Default password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 --decode)"

