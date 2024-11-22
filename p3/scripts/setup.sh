sudo pacman -Syu --noconfirm
sudo pacman -Rns --noconfirm docker containerd runc kubectl
sudo pacman -S --noconfirm docker
sudo systemctl enable docker
sudo systemctl start docker
k3d cluster delete -a
sudo rm $(whereis k3d | cut -d ' ' -f 2)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
sudo pacman -S --noconfirm kubectl
echo "Setup complete!"