#!/bin/bash

# Create new project in GitLab
GITLAB_TOKEN=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 --decode)

# Clone your Part 3 repo and push to GitLab
git clone https://github.com/yourusername/your-p3-repo.git
cd your-p3-repo
git remote add gitlab http://root:${GITLAB_TOKEN}@192.168.56.110:8080/root/iot-p3.git
git push -u gitlab main

# Update ArgoCD configuration
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-p3-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'http://192.168.56.110:8080/root/iot-p3.git'
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