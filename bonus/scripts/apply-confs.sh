#!/bin/bash

# Wait for GitLab webservice to be ready
echo "Waiting for GitLab to be ready..."
until kubectl get pods -n gitlab -l app=webservice -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -q true; do
    sleep 10
done

# Apply Kubernetes service account and RBAC configurations
kubectl apply -f /vagrant/confs/gitlab-admin-service-account.yaml
kubectl apply -f /vagrant/confs/gitlab-ingress.yaml

# Get the service account token for GitLab Kubernetes integration
TOKEN=$(kubectl -n gitlab get secret $(kubectl -n gitlab get secret | grep gitlab-admin | awk '{print $1}') -o jsonpath='{.data.token}' | base64 --decode)
echo "GitLab Admin Service Account Token: $TOKEN"

# Wait for Argo CD server to be ready
echo "Waiting for Argo CD to be ready..."
until kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep -q true; do
    sleep 10
done

# Get Argo CD admin password
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD admin password: $ARGOCD_PWD"

# Apply Argo CD application configuration
kubectl apply -f /vagrant/confs/argocd-gitlab-app.yaml

# Display final configuration information
echo "All configurations have been applied!"
echo "GitLab URL: http://192.168.56.110:8080"
echo "Default root password: gitlabadmin"
echo "Use the token above to configure the Kubernetes integration in GitLab" 