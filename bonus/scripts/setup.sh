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
  --port "8443:443@loadbalancer" \  # For HTTPS
  --port "8080:80@loadbalancer" \   # For HTTP
  --port "8888:8888@loadbalancer" \ # For our application
  --agents 2                        # We want 2 worker nodes

# Create necessary namespaces
kubectl create namespace gitlab    # For GitLab itself

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

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
    password: "gitlabadmin"
  kubernetes:
    enabled: true
    inCluster: true
  email:
    from: "gitlab@gitlab.local"
    display_name: "GitLab"
    reply_to: "noreply@gitlab.local"

certmanager:
  install: false
  installCRDs: false

certmanager-issuer:
  email: "gitlab@gitlab.local"

nginx-ingress:
  enabled: false

gitlab-runner:
  install: true
  runners:
    config: |
      [[runners]]
        [runners.kubernetes]
        image = "ubuntu:20.04"

# Storage configurations
postgresql:
  persistence:
    size: 8Gi

redis:
  persistence:
    size: 5Gi

minio:
  persistence:
    size: 10Gi

# Component scaling
gitlab:
  webservice:
    minReplicas: 1
    maxReplicas: 1
    ingress:
      enabled: true
      tls:
        enabled: false
  sidekiq:
    minReplicas: 1
    maxReplicas: 1
  gitlab-shell:
    minReplicas: 1
    maxReplicas: 1
    service:
      type: ClusterIP
      externalTrafficPolicy: Cluster

registry:
  enabled: true
  tls:
    enabled: false

shared-secrets:
  enabled: true
  env: production
EOF

# Create root password secret
kubectl create secret generic gitlab-root-password \
  --from-literal=password=gitlabadmin \
  -n gitlab

# Install GitLab using Helm
retry helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --namespace gitlab \
  -f /vagrant/confs/gitlab-values.yaml

# Wait for GitLab to be ready
echo "Waiting for GitLab pods to be ready..."
kubectl wait --for=condition=ready pod -l release=gitlab -n gitlab --timeout=600s

# Show access information
echo "GitLab is being installed. This may take several minutes."
echo "Once ready, access GitLab at: http://192.168.56.110:8080"
echo "Default root password is: gitlabadmin"

# Run additional configuration
chmod +x /vagrant/scripts/apply-confs.sh
/vagrant/scripts/apply-confs.sh 