# Inception of Things (IoT) Project

## Project Overview
This project focuses on learning and implementing container orchestration using Kubernetes, specifically with K3s and K3d. It's divided into three main parts, each building upon the previous one to create a complete infrastructure setup.

## Technical Concepts

### Key Technologies Used
- **Vagrant**: A tool for building and managing virtual machine environments
- **K3s**: A lightweight Kubernetes distribution designed for IoT and edge computing
- **K3d**: A tool to run K3s in Docker, making it easier to create single- or multi-node K3s clusters
- **Argo CD**: A declarative continuous delivery tool for Kubernetes
- **Docker**: A platform for developing, shipping, and running applications in containers

## Project Structure

### Part 1: K3s and Vagrant Setup
- Creates two virtual machines using Vagrant
- Implements a server-worker architecture
- **Server Node (S)**:
  - IP: 192.168.56.110
  - Role: K3s controller
- **Worker Node (SW)**:
  - IP: 192.168.56.111
  - Role: K3s agent

### Part 2: K3s and Application Deployment
- Sets up three web applications in K3s
- Implements Ingress routing based on hostnames
- Configuration:
  - app1.com → Application 1 (1 replica)
  - app2.com → Application 2 (3 replicas)
  - Default → Application 3 (1 replica)
- All applications accessible via IP 192.168.56.110

### Part 3: K3d and Argo CD Implementation
- Moves from Vagrant/K3s to K3d
- Sets up continuous deployment with Argo CD
- Creates two Kubernetes namespaces:
  - `argocd`: For Argo CD components
  - `dev`: For application deployment
- Implements automated deployment from GitHub repository
- Supports version management (v1 and v2 of applications)

## Directory Structure

bonus/

3. Usage Instructions
Start the environment:
Bash
Access GitLab:
Open browser: http://192.168.56.110:8080
Login with:
Username: root
Password: (from script output)
Configure GitLab:
Go to Admin Area > Kubernetes
Add new cluster:
API URL: https://kubernetes.default.svc
Token: (from script output)
Project namespace: gitlab
Migrate your Part 3 project:
Create new project in GitLab
Push your code from Part 3
Update Argo CD configuration to use GitLab repository
4. Understanding the Flow
Infrastructure Layer:
K3d creates local Kubernetes cluster
GitLab runs as containerized application
Helm manages the deployment
Integration Layer:
GitLab connects to Kubernetes cluster
Argo CD watches GitLab repository
Kubernetes executes deployments
Application Layer:
Your applications run in containers
GitLab CI/CD manages builds
Argo CD handles deployments
This setup creates a complete local DevOps environment with:
Source Control (GitLab)
CI/CD (GitLab CI)
Container Registry (GitLab Registry)
Kubernetes Management (K3d)
GitOps (Argo CD)# Kubernetes
___
# Full Tutorial: Setting Up GitLab Locally, Connecting It with ArgoCD, and Testing with a Website Running on Docker

This tutorial provides a step-by-step guide to:

    Set up GitLab locally using Kubernetes (k3d).

    Connect GitLab with ArgoCD for GitOps-based deployments.

    Test the setup using a simple website running on a Docker container hosted on Nginx.

Prerequisites

Before starting, ensure you have the following installed:

    Docker: For containerization.

    k3d: A lightweight Kubernetes distribution for local development.

    kubectl: Kubernetes command-line tool.

    Helm: Package manager for Kubernetes.

    Git: Version control system.

Step 1: Install Dependencies
1.1 Install Docker

If Docker is not installed, run the following commands:
bash
Copy

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

1.2 Install k3d

Install k3d to create a local Kubernetes cluster:
bash
Copy

wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

1.3 Install kubectl

Install kubectl to interact with your Kubernetes cluster:
bash
Copy

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

1.4 Install Helm

Install Helm to manage Kubernetes applications:
bash
Copy

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

Step 2: Set Up a Local Kubernetes Cluster
2.1 Create a k3d Cluster

Create a minimal Kubernetes cluster using k3d:
bash
Copy

k3d cluster create gitlab-cluster \
    --servers 1 \
    --agents 1 \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer"

2.2 Verify the Cluster

Check if the cluster is running:
bash
Copy

kubectl get nodes

2.3 Create Namespaces

Create namespaces for GitLab, ArgoCD, and your application:
bash
Copy

kubectl create namespace gitlab
kubectl create namespace argocd
kubectl create namespace dev

Step 3: Deploy GitLab
3.1 Create GitLab Configuration

Create a gitlab-values.yaml file to configure GitLab:
yaml
Copy

global:
  hosts:
    domain: localhost
    https: false
    gitlab:
      name: gitlab.localhost
      https: false
    externalUrl: http://gitlab.localhost:8080
  ingress:
    configureCertmanager: false
    class: nginx
    enabled: false
    tls:
      enabled: false

certmanager:
  install: false

nginx-ingress:
  enabled: false

gitlab-runner:
  install: false

prometheus:
  install: false

gitlab:
  webservice:
    hosts:
      - gitlab.localhost

3.2 Install GitLab Using Helm

Add the GitLab Helm repository and deploy GitLab:
bash
Copy

helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --timeout 600s \
    --values gitlab-values.yaml \
    --wait

3.3 Access GitLab

    Get the GitLab root password:
    bash
    Copy

    kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode

    Access GitLab at:
    Copy

    http://gitlab.localhost:8080

        Username: root

        Password: (from the command above)

Step 4: Deploy ArgoCD
4.1 Install ArgoCD

Install ArgoCD in the argocd namespace:
bash
Copy

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

4.2 Configure ArgoCD


    Create an ArgoCD application to sync your GitLab repository:
    yaml
    Copy

    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: iot
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: 'http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot.git'
        targetRevision: HEAD
        path: confs
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true

4.3 Access ArgoCD

    Set up port forwarding:
    bash
    Copy

    kubectl port-forward svc/argocd-server -n argocd 8888:443

    Access ArgoCD at:
    Copy

    https://localhost:8888

        Username: admin

        Password: (retrieve using kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

Step 5: Deploy a Website Using Nginx
5.1 Create a Dockerfile

Create a Dockerfile for your website:
dockerfile
Copy

FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80

5.2 Build and Push the Docker Image

    Build the Docker image:
    bash
    Copy

    docker build -t hamid1337/website:v2 .

    Push the image to Docker Hub:
    bash
    Copy

    docker push hamid1337/website:v2

5.3 Deploy the Website to Kubernetes

    Create a Kubernetes deployment and service:
    yaml
    Copy

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: wil-playground
      namespace: dev
    spec:
      selector:
        matchLabels:
          app: wil-playground
      template:
        metadata:
          labels:
            app: wil-playground
        spec:
          containers:
          - name: wil
            image: hamid1337/website:v2
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: svc-wil-playground
      namespace: dev
    spec:
      selector:
        app: wil-playground
      ports:
        - protocol: TCP
          port: 3030
          targetPort: 80

    Apply the configuration:
    bash
    Copy

    kubectl apply -f deployment.yaml -n dev

    Access the website at:
    Copy

    http://localhost:3030

Step 6: Clean Up

    Delete the k3d cluster:
    bash
    Copy

    k3d cluster delete gitlab-cluster

    Remove unused Docker images:
    bash
    Copy

    docker system prune -af

Conclusion

You’ve successfully set up GitLab locally, connected it with ArgoCD, and deployed a website using Docker and Kubernetes. This setup is ideal for local development and testing GitOps workflows.
# Kubernetes

Docker Image Update and Kubernetes Deployment Tutorial

This guide walks you through the process of:

    Updating a Docker image.

    Pushing the updated image to Docker Hub.

    Deploying the updated image to Kubernetes.

Prerequisites

    Docker installed on your machine.

    A Docker Hub account.

    Kubernetes cluster (e.g., Minikube, k3d, or any other cluster).

    Basic knowledge of Docker and Kubernetes.

Step 1: Update Your Application

    Make the necessary changes to your application files (e.g., index.html).

    Test the changes locally to ensure they work as expected.

Step 2: Rebuild the Docker Image

    Navigate to the directory containing your Dockerfile and application files.

    Rebuild the Docker image with a version tag (e.g., v2):
    bash
    Copy

    docker build -t hamid1337/website:v2 .

    Here:

        hamid1337/website is your Docker Hub repository name.

        v2 is the version tag (you can use any versioning scheme, e.g., v1, v2, etc.).

Step 3: Push the Updated Image to Docker Hub

    Log in to Docker Hub:
    bash
    Copy

    docker login

    Enter your Docker Hub username and password when prompted.

    Push the versioned image to Docker Hub:
    bash
    Copy

    docker push hamid1337/website:v2

    (Optional) Update the latest tag:

        Tag the versioned image as latest:
        bash
        Copy

        docker tag hamid1337/website:v2 hamid1337/website:latest

        Push the latest tag to Docker Hub:
        bash
        Copy

        docker push hamid1337/website:latest

    Verify the update on Docker Hub:

        Go to your Docker Hub repository:
        Copy

        https://hub.docker.com/r/hamid1337/website

        Check the Tags tab to confirm that the new tag (v2 or latest) has been updated.

Step 4: Update the Kubernetes Deployment

    Update your Kubernetes deployment YAML file to use the new image tag.

    Example YAML (deployment.yaml):
    yaml
    Copy

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: wil-playground
      namespace: dev
    spec:
      selector:
        matchLabels:
          app: wil-playground
      template:
        metadata:
          labels:
            app: wil-playground
        spec:
          containers:
          - name: wil
            image: hamid1337/website:v2  # Use the updated image tag
            ports:
            - containerPort: 80

    Apply the updated deployment to your Kubernetes cluster:
    bash
    Copy

    kubectl apply -f deployment.yaml -n dev

    Restart the deployment to ensure Kubernetes pulls the updated image:
    bash
    Copy

    kubectl rollout restart deployment/wil-playground -n dev

Step 5: Verify the Deployment

    Check the status of the pods:
    bash
    Copy

    kubectl get pods -n dev

    Describe the pod to confirm it's using the updated image:
    bash
    Copy

    kubectl describe pod <pod-name> -n dev

    Look for the Image field under the Containers section.

    Check the logs for errors:
    bash
    Copy

    kubectl logs <pod-name> -n dev

    Access the application:

        If using a service, check the service configuration:
        bash
        Copy

        kubectl describe svc svc-wil-playground -n dev

        Access the application at the appropriate URL (e.g., http://localhost:3030).

Step 6: Clean Up (Optional)

    Remove old images from your local machine:
    bash
    Copy

    docker rmi hamid1337/website:v1  # Replace v1 with the old tag

    Remove unused Docker images:
    bash
    Copy

    docker image prune -f

    Delete old Kubernetes resources if no longer needed:
    bash
    Copy

    kubectl delete deployment wil-playground -n dev
    kubectl delete svc svc-wil-playground -n dev

Cheat Sheet

Here’s a quick cheat sheet for the commands:
Action	Command
Build Docker image	docker build -t hamid1337/website:v2 .
Log in to Docker Hub	docker login
Push image to Docker Hub	docker push hamid1337/website:v2
Tag image as latest	docker tag hamid1337/website:v2 hamid1337/website:latest
Push latest tag	docker push hamid1337/website:latest
Apply Kubernetes deployment	kubectl apply -f deployment.yaml -n dev
Restart deployment	kubectl rollout restart deployment/wil-playground -n dev
Check pods	kubectl get pods -n dev
Describe pod	kubectl describe pod <pod-name> -n dev
Check logs	kubectl logs <pod-name> -n dev
Describe service	kubectl describe svc svc-wil-playground -n dev
Tips for Future Updates

    Always use version tags (e.g., v1, v2) instead of relying solely on latest.

    Test your changes locally before pushing to Docker Hub.

    Use kubectl rollout restart to force Kubernetes to pull the updated image.

    Regularly clean up unused Docker images and Kubernetes resources.

Conclusion

By following this tutorial, you can easily update your Docker image, push it to Docker Hub, and deploy it to Kubernetes. Save this README as a reference, and you'll never forget the steps! 😊
