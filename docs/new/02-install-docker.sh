#!/bin/bash

# =============================================================================
# 🐳 STEP 2: DOCKER & NVIDIA CONTAINER TOOLKIT
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
print_info() { echo -e "${BLUE}  ℹ${NC} $1"; }

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🐳 Step 2: Docker & NVIDIA Container Toolkit                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Docker Installation
# -----------------------------------------------------------------------------
print_step "Installing Docker..."

if command -v docker &> /dev/null; then
    print_success "Docker already installed: $(docker --version | cut -d' ' -f3)"
else
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add repository
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed"
    print_warning "Logout and login for docker group to take effect"
fi

# -----------------------------------------------------------------------------
# NVIDIA Container Toolkit
# -----------------------------------------------------------------------------
print_step "Installing NVIDIA Container Toolkit..."

if dpkg -l | grep -q nvidia-container-toolkit; then
    print_success "NVIDIA Container Toolkit already installed"
else
    # Add repository
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    
    # Configure Docker
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    
    print_success "NVIDIA Container Toolkit installed"
fi

# -----------------------------------------------------------------------------
# Test GPU in Docker
# -----------------------------------------------------------------------------
print_step "Testing GPU in Docker..."

if sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &>/dev/null; then
    print_success "GPU accessible in Docker!"
    sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
else
    print_warning "GPU not detected in Docker. Try logout/login or reboot."
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 2 Complete!                                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next: ./03-install-ollama.sh"
echo ""
