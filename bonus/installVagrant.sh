#!/bin/bash

# Update system
echo "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Add HashiCorp GPG key
echo "Adding HashiCorp GPG key..."
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update package list
sudo apt-get update

# Install dependencies
echo "Installing dependencies..."
sudo apt-get install -y build-essential dkms

# Install VirtualBox
echo "Installing VirtualBox..."
sudo apt-get install -y virtualbox virtualbox-ext-pack

# Install Vagrant
echo "Installing Vagrant..."
sudo apt-get install -y vagrant

# Add user to vboxusers group
sudo usermod -aG vboxusers $USER

# Verify installations
echo "Verifying installations..."
vagrant --version
vboxmanage --version

echo "Installation complete!"
echo "Please log out and log back in for group changes to take effect."
echo "You can test the installation with: vagrant init hashicorp/bionic64"