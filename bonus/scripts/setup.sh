#!/bin/bash

# Install required tools
echo "Installing required tools..."

# Add GitLab repository for Debian
curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

# Install GitLab Community Edition
sudo EXTERNAL_URL="http://gitlab.local:8080" apt-get install -y gitlab-ce

# Copy GitLab configuration
sudo cp /vagrant/confs/gitlab.rb /etc/gitlab/gitlab.rb

# Configure GitLab
sudo gitlab-ctl reconfigure

# Wait for GitLab services to be healthy
echo "Waiting for GitLab services to be ready..."
timeout 300 bash -c 'until sudo gitlab-ctl status > /dev/null 2>&1; do sleep 2; done'

# Check individual services
echo "Checking GitLab services..."
sudo gitlab-ctl status

# Install Docker for Debian
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add current user to docker group
sudo usermod -aG docker vagrant

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create k3d cluster
k3d cluster create iot-gitlab \
    --servers 1 \
    --agents 2 \
    --port 8081:80@loadbalancer \
    --port 8443:443@loadbalancer \
    --port 8888:8888@loadbalancer

# Create namespaces
kubectl create namespace gitlab
kubectl create namespace argocd
kubectl create namespace dev

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Configure GitLab integration with K8s
kubectl create serviceaccount gitlab-admin -n gitlab
kubectl create clusterrolebinding gitlab-admin-binding \
    --clusterrole=cluster-admin \
    --serviceaccount=gitlab:gitlab-admin

# Get the token for GitLab K8s integration
GITLAB_KUBE_TOKEN=$(kubectl -n gitlab get secret \
    $(kubectl -n gitlab get secret | grep gitlab-admin | awk '{print $1}') \
    -o jsonpath='{.data.token}' | base64 --decode)

# Configure GitLab with K8s token
sudo gitlab-rails runner "
token = ENV['GITLAB_KUBE_TOKEN']
Gitlab::CurrentSettings.current_application_settings.update!(
  kubernetes_api_url: 'https://kubernetes.default.svc',
  kubernetes_token: token,
  kubernetes_namespace: 'gitlab'
)
"

# Wait for Argo CD to be ready
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s

# Configure Argo CD service
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Add local GitLab domain to hosts file
echo "192.168.56.110 gitlab.local" | sudo tee -a /etc/hosts

echo "Setup complete! Access points:"
echo "GitLab: http://gitlab.local:8081"
echo "Argo CD: http://192.168.56.110:8081/argocd"

# Print initial root password for GitLab
echo -e "\nGitLab root password:"
sudo cat /etc/gitlab/initial_root_password

# Print Argo CD admin password
echo -e "\nArgo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -ojsonpath="{.data.password}" | base64 --decode; echo