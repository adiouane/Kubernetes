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
