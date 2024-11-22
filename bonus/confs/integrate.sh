#!/bin/bash

# Wait for GitLab to be ready
until kubectl get pods -n gitlab | grep gitlab-webservice | grep Running; do
  echo "Waiting for GitLab to be ready..."
  sleep 10
done

# Get root password
ROOT_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 --decode)
echo "GitLab root password: $ROOT_PASSWORD"

# Configure GitLab with K8s cluster
kubectl create serviceaccount gitlab-admin
kubectl create clusterrolebinding gitlab-admin --clusterrole=cluster-admin --serviceaccount=default:gitlab-admin
SECRET_NAME=$(kubectl get serviceaccount gitlab-admin -o jsonpath='{.secrets[0].name}')
TOKEN=$(kubectl get secret $SECRET_NAME -o jsonpath='{.data.token}' | base64 --decode)
echo "Kubernetes integration token: $TOKEN"