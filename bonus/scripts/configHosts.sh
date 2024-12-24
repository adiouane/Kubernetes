#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Add GitLab hostname to /etc/hosts if it doesn't exist
if ! grep -q "gitlab.localhost" /etc/hosts; then
    echo "127.0.0.1 gitlab.localhost" >> /etc/hosts
    echo "GitLab hostname added to /etc/hosts"
else
    echo "GitLab hostname already exists in /etc/hosts"
fi

# Display current hosts file
echo -e "\nCurrent /etc/hosts file:"
cat /etc/hosts