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
# Kubernetes
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
