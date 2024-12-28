#!/bin/bash
#deploy script
# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

# Wait for GitLab
echo "Waiting for GitLab..."
until curl --output /dev/null --silent --head --fail http://gitlab.gitlab.local:80; do
    printf '.'
    sleep 5
done
echo -e "\nGitLab is ready!"

# Get GitLab password
gitlab_password=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode)
echo "GitLab password: $gitlab_password"

# Create Personal Access Token
echo "Creating GitLab token..."
TOKEN_RESPONSE=$(curl -s --request POST "http://gitlab.gitlab.local:80/api/v4/personal_access_tokens" \
  --header "Content-Type: application/json" \
  --user "root:${gitlab_password}" \
  --data '{
    "name": "gitlab-token",
    "scopes": ["api", "read_user", "read_repository", "write_repository"]
  }')

export GITLAB_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.token')

# Create project structure
mkdir -p /tmp/p3/{src/public,confs}
cd /tmp/p3

# Create demo application files
cat > src/public/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>IoT P3 Demo</title>
    <style>
        body { 
            font-family: Arial; 
            text-align: center; 
            margin-top: 50px;
            background-color: #f0f0f0;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            max-width: 600px;
            margin: 0 auto;
        }
        .version { 
            color: #666;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to IoT P3 Demo</h1>
        <p>This is version 1.0</p>
        <div class="version">Deployed by ArgoCD</div>
    </div>
</body>
</html>
EOF

# Create Node.js files
cat > src/index.js <<EOF
const express = require('express');
const app = express();
const port = 3000;

app.use(express.static('public'));
app.listen(port, () => {
    console.log(\`Server running at http://localhost:\${port}\`);
});
EOF

cat > src/package.json <<EOF
{
  "name": "adiouane-bonus-website",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.17.1"
  }
}
EOF

# Create Dockerfile
cat > Dockerfile <<EOF
FROM node:16-alpine
WORKDIR /app
COPY src/package*.json ./
RUN npm install
COPY src .
EXPOSE 3000
CMD ["node", "index.js"]
EOF

# Create Kubernetes manifests
cat > confs/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-website
  namespace: dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-website
  template:
    metadata:
      labels:
        app: demo-website
    spec:
      containers:
      - name: demo-website
        image: registry.gitlab.local:5050/root/adiouane-bonus-website:latest
        ports:
        - containerPort: 3000
EOF

cat > confs/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: demo-website
  namespace: dev
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
  selector:
    app: demo-website
EOF

# Create GitLab CI
cat > .gitlab-ci.yml <<EOF
image: docker:20.10.16

services:
  - docker:20.10.16-dind

variables:
  DOCKER_TLS_CERTDIR: ""

stages:
  - build
  - deploy

build:
  stage: build
  script:
    - docker login -u root -p ${gitlab_password} registry.gitlab.local:5050
    - docker build -t registry.gitlab.local:5050/root/adiouane-bonus-website:latest .
    - docker push registry.gitlab.local:5050/root/adiouane-bonus-website:latest

deploy:
  stage: deploy
  script:
    - apk add --no-cache curl
    - curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl
    - chmod +x ./kubectl
    - mv ./kubectl /usr/local/bin/kubectl
    - kubectl apply -f confs/
EOF

# Create GitLab project
echo "Creating GitLab project..."
curl -X POST "http://gitlab.gitlab.local:80/api/v4/projects" \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --data "name=adiouane-bonus-website"
check_status "GitLab project created"

# Setup git and push
git init
git config --global user.email "admin@example.com"
git config --global user.name "Administrator"
git add .
git commit -m "Initial deployment"
git remote add origin "http://root:${gitlab_password}@gitlab.gitlab.local:80/root/adiouane-bonus-website.git"
git push -u origin master
check_status "Code pushed to GitLab"

# Create ArgoCD configuration
cat > confs/argocd.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: adiouane-bonus-website
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'http://gitlab.gitlab.local:80/root/adiouane-bonus-website.git'
    targetRevision: HEAD
    path: confs
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Setup ArgoCD
kubectl create namespace argocd 2>/dev/null || true
kubectl create namespace dev 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
kubectl apply -f confs/argocd.yaml
check_status "ArgoCD configured"

echo -e "${GREEN}Setup completed successfully!${NC}"
echo "To test changes:"
echo "1. Edit src/public/index.html"
echo "2. Commit and push changes"
echo "3. ArgoCD will automatically deploy the new version"

echo "to access to argocd use the following command"
echo "kubectl port-forward svc/argocd-server -n argocd 8888:443"
echo "to get password use the following command"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"