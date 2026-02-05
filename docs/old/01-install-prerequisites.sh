#!/bin/bash

# =============================================================================
# 📦 INSTALL PREREQUISITES ONLY
# Docker + NVIDIA Container Toolkit
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
print_error() { echo -e "${RED}  ✗${NC} $1"; }

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  📦 Installing Prerequisites           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Step 1: Basic packages
# -----------------------------------------------------------------------------
print_step "Installing basic packages..."
sudo apt update
sudo apt install -y \
    curl wget git build-essential \
    software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release
print_success "Basic packages installed"

# -----------------------------------------------------------------------------
# Step 2: Check NVIDIA Driver
# -----------------------------------------------------------------------------
print_step "Checking NVIDIA Driver..."
if command -v nvidia-smi &> /dev/null; then
    print_success "NVIDIA Driver detected:"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    print_error "NVIDIA Driver NOT found!"
    echo ""
    echo "Install driver dengan:"
    echo "  sudo add-apt-repository -y ppa:graphics-drivers/ppa"
    echo "  sudo apt update"
    echo "  sudo ubuntu-drivers autoinstall"
    echo "  sudo reboot"
    echo ""
    read -p "Install sekarang? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo add-apt-repository -y ppa:graphics-drivers/ppa
        sudo apt update
        sudo ubuntu-drivers autoinstall
        print_warning "Driver installed. Reboot required!"
        read -p "Reboot sekarang? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Docker
# -----------------------------------------------------------------------------
print_step "Installing Docker..."
if command -v docker &> /dev/null; then
    print_success "Docker already installed: $(docker --version)"
else
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker repository
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed"
    print_warning "Logout dan login kembali agar docker group aktif"
fi

# -----------------------------------------------------------------------------
# Step 4: NVIDIA Container Toolkit
# -----------------------------------------------------------------------------
print_step "Installing NVIDIA Container Toolkit..."
if dpkg -l | grep -q nvidia-container-toolkit; then
    print_success "NVIDIA Container Toolkit already installed"
else
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    
    print_success "NVIDIA Container Toolkit installed"
fi

# -----------------------------------------------------------------------------
# Step 5: Test GPU in Docker
# -----------------------------------------------------------------------------
print_step "Testing GPU in Docker..."
if sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &>/dev/null; then
    print_success "GPU berhasil terdeteksi di Docker!"
    sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
else
    print_warning "GPU belum terdeteksi. Coba logout/login atau reboot."
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Prerequisites Complete!            ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Next step: ./02-install-ollama.sh"
echo ""
