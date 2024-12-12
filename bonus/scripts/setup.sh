#!/bin/bash

# First, update the system and install basic tools
apt-get update
apt-get install -y curl wget git

# Install Docker - we'll need this to run our containers
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
# Add vagrant user to docker group so we don't need sudo
usermod -aG docker vagrant

# Install kubectl - this is our main tool for managing Kubernetes
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Helm - we'll use this to install GitLab
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install k3d - this lets us run Kubernetes in Docker
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create our k3d cluster with port forwarding
k3d cluster create gitlab-cluster \
    --port "8443:443@loadbalancer" \
    --port "8080:80@loadbalancer" \
    --port "8888:8888@loadbalancer" \
    --agents 2

# Wait for the cluster to be ready
sleep 20

# Configure kubectl to use the new cluster
k3d kubeconfig merge gitlab-cluster --kubeconfig-switch-context

# Create necessary namespaces
kubectl create namespace gitlab

# Create a retry function - useful for unreliable network operations
function retry {
  local n=1
  local max=5
  local delay=15
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        sleep $delay;
      else
        echo "The command has failed after $n attempts."
        return 1
      fi
    }
  done
}

# Add GitLab Helm repository
retry helm repo add gitlab https://charts.gitlab.io/
retry helm repo update

# Create GitLab configuration
cat > /vagrant/confs/gitlab-values.yaml << 'EOF'
global:
  hosts:
    domain: gitlab.local
    https: false
    externalIP: 192.168.56.110
  initialRootPassword:
    secret: gitlab-root-password
    key: password
  kubernetes:
    enabled: true
    inCluster: true
  email:
    from: gitlab@gitlab.local
    display_name: GitLab

  # Disable unnecessary features
  grafana:
    enabled: false
  kas:
    enabled: false
  praefect:
    enabled: false
  prometheus:
    enabled: false

# Disable cert-manager
certmanager:
  install: false
  installCRDs: false

# Add certmanager-issuer configuration
certmanager-issuer:
  email: gitlab@gitlab.local

# Disable NGINX ingress as we're using Traefik
nginx-ingress:
  enabled: false

# Disable GitLab Runner initially
gitlab-runner:
  install: false

# Minimal storage configuration
postgresql:
  persistence:
    size: 500Mi
    storageClass: local-path
  resources:
    requests:
      cpu: 50m
      memory: 200Mi
    limits:
      cpu: 100m
      memory: 300Mi

redis:
  persistence:
    size: 500Mi
    storageClass: local-path
  resources:
    requests:
      cpu: 50m
      memory: 100Mi
    limits:
      cpu: 100m
      memory: 200Mi

minio:
  persistence:
    size: 1Gi
    storageClass: local-path
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 100m
      memory: 256Mi

# Ultra minimal component configuration
gitlab:
  toolbox:
    enabled: false
    backups:
      enabled: false

  webservice:
    minReplicas: 1
    maxReplicas: 1
    deployment:
      minReplicas: 1
      maxReplicas: 1
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 200m
        memory: 400Mi
    workhorse:
      resources:
        requests:
          cpu: 50m
          memory: 100Mi
        limits:
          cpu: 100m
          memory: 200Mi

  sidekiq:
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 50m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  gitlab-shell:
    minReplicas: 1
    maxReplicas: 1
    resources:
      requests:
        cpu: 50m
        memory: 50Mi
      limits:
        cpu: 100m
        memory: 100Mi

registry:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 50Mi
    limits:
      cpu: 100m
      memory: 100Mi

# Disable monitoring
prometheus:
  install: false

# Disable Gitaly extra storage
gitaly:
  persistence:
    size: 1Gi
    storageClass: local-path
  resources:
    requests:
      cpu: 50m
      memory: 200Mi
    limits:
      cpu: 100m
      memory: 300Mi
EOF

# Create root password secret before installing GitLab
kubectl create secret generic gitlab-root-password \
  --from-literal=password=gitlabadmin \
  -n gitlab

# Add this before GitLab installation
# Check available storage
available_storage=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
required_storage=5  # Minimum GB required

if [ "$available_storage" -lt "$required_storage" ]; then
    echo -e "${RED}Error: Not enough storage available${NC}"
    echo "Required: ${required_storage}GB"
    echo "Available: ${available_storage}GB"
    exit 1
fi

# Install GitLab using Helm
retry helm upgrade --install gitlab gitlab/gitlab \
  --timeout 1200s \
  --namespace gitlab \
  -f gitlab-values.yaml \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.externalIP=192.168.56.110

# Wait for GitLab to be ready
echo "Waiting for GitLab pods to be ready (this may take several minutes)..."
kubectl wait --for=condition=ready pod -l release=gitlab -n gitlab --timeout=600s 2>&1 | \
while read -r line; do
    echo "Status: $line"
done

# Show access information
echo "GitLab is being installed. This may take several minutes."
echo "Once ready, access GitLab at: http://192.168.56.110:8080"
echo "Default root password is: gitlabadmin"