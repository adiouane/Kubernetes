#!/bin/bash
#setupgitlab
# Update system
sudo apt-get update
sudo apt-get install -y curl

# Add GitLab Helm repository
helm repo remove gitlab || true
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Create gitlab namespace
kubectl create namespace gitlab

# Create a values file for GitLab configuration
cat << EOF > gitlab-values.yaml
global:
  hosts:
    domain: gitlab.local
    https: false
    externalIP: $(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  edition: ce
  time_zone: UTC
  shell:
    port: 22
  ingress:
    configureCertmanager: false
    class: "nginx"
    enabled: true
    tls:
      enabled: false

certmanager-issuer:
  email: your.email@example.com 

certmanager:
  install: false

nginx-ingress:
  enabled: false

gitlab-runner:
  install: true

postgresql:
  persistence:
    size: 8Gi

redis:
  persistence:
    size: 5Gi

gitlab:
  webservice:
    ingress:
      enabled: true
      tls:
        enabled: false
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 200m
        memory: 1.25Gi
      limits:
        cpu: 1
        memory: 2Gi
  sidekiq:
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 50m
        memory: 650M
      limits:
        cpu: 500m
        memory: 1Gi
  gitaly:
    persistence:
      size: 10Gi
    resources:
      requests:
        cpu: 100m
        memory: 200M
      limits:
        cpu: 400m
        memory: 1Gi

minio:
  resources:
    requests:
      memory: 64Mi
      cpu: 10m
EOF

# Install GitLab using Helm
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 600s \
  --values gitlab-values.yaml

# Wait for GitLab to be ready (using a more reliable wait)
echo "Waiting for GitLab pods to be ready..."
sleep 30  # Initial wait for pods to start creating

# Wait for specific deployments
kubectl wait --for=condition=available --timeout=900s deployment -l app=webservice -n gitlab

echo "GitLab installation completed!"
echo
echo "Initial root password: gitlab123456"
echo
echo "GitLab URLs:"
kubectl get ingress -n gitlab

echo "
To access GitLab:
1. Add to your /etc/hosts file:
$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') gitlab.local minio.gitlab.local registry.gitlab.local kas.gitlab.local

2. Access GitLab at: http://gitlab.local
3. Login with:
   Username: root
   Password: gitlab123456"

# get password 
echo "GitLab root password: $(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode ; echo)"

# Add to the hosts file these following lines
sudo bash -c "echo '$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}') gitlab.local minio.gitlab.local registry.gitlab.local kas.gitlab.local gitlab.gitlab.local' >> /etc/hosts"
sudo bash -c "echo '127.0.0.1 gitlab.local minio.gitlab.local registry.gitlab.local kas.gitlab.local gitlab.gitlab.local' >> /etc/hosts"


