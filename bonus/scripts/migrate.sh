#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check if a command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y jq
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    else
        echo "Please install jq manually"
        exit 1
    fi
fi

# Wait for GitLab to be ready and get root password
echo "Waiting for GitLab to be ready..."
while true; do
    GITLAB_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode)
    if [ ! -z "$GITLAB_PASSWORD" ]; then
        break
    fi
    echo "Waiting for GitLab password to be available..."
    sleep 10
done

echo "GitLab root password: $GITLAB_PASSWORD"

# Wait for GitLab to be accessible
echo "Waiting for GitLab to be accessible..."
until curl -s --head --fail http://gitlab.localhost:8888 &>/dev/null; do
    echo "Waiting for GitLab to be accessible..."
    sleep 10
done

# Wait a bit more to ensure GitLab is fully operational
sleep 30

# Create personal access token
echo "Creating personal access token..."
TOKEN_RESPONSE=$(curl -s --request POST "http://gitlab.localhost:8888/oauth/token" \
  --header "Content-Type: application/json" \
  --data "{
    \"grant_type\": \"password\",
    \"username\": \"root\",
    \"password\": \"$GITLAB_PASSWORD\"
  }")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Failed to get access token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

# Create project
echo "Creating project..."
PROJECT_RESPONSE=$(curl -s --request POST "http://gitlab.localhost:8888/api/v4/projects" \
  --header "Authorization: Bearer $ACCESS_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"iot-p3\",
    \"visibility\": \"public\"
  }")

PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.id')

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Failed to create project${NC}"
    echo "Response: $PROJECT_RESPONSE"
    exit 1
fi

echo -e "\n${GREEN}GitLab setup complete!${NC}"
echo "----------------------------------------"
echo "Access GitLab at: http://gitlab.localhost:8888"
echo "Username: root"
echo "Password: $GITLAB_PASSWORD"
echo "Project created: iot-p3"
echo "----------------------------------------"