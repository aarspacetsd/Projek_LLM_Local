#!/bin/bash

# =============================================================================
# 📦 STEP 1: PREREQUISITES & NVIDIA DRIVER
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
print_error() { echo -e "${RED}  ✗${NC} $1"; }

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  📦 Step 1: Prerequisites & NVIDIA Driver                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# System Update
# -----------------------------------------------------------------------------
print_step "Updating system..."
sudo apt update && sudo apt upgrade -y
print_success "System updated"

# -----------------------------------------------------------------------------
# Install Prerequisites
# -----------------------------------------------------------------------------
print_step "Installing prerequisites..."
sudo apt install -y \
    curl wget git build-essential \
    software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release \
    python3 python3-pip python3-venv \
    jq htop nvtop tmux

print_success "Prerequisites installed"

# -----------------------------------------------------------------------------
# NVIDIA Driver
# -----------------------------------------------------------------------------
print_step "Checking NVIDIA Driver..."

if command -v nvidia-smi &> /dev/null; then
    print_success "NVIDIA Driver already installed:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | sed 's/^/    /'
else
    print_warning "NVIDIA Driver not found. Installing..."
    
    sudo add-apt-repository -y ppa:graphics-drivers/ppa
    sudo apt update
    sudo ubuntu-drivers autoinstall
    
    echo ""
    print_warning "NVIDIA Driver installed. REBOOT REQUIRED!"
    echo ""
    read -p "Reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        echo ""
        echo "Please reboot manually, then run: ./02-install-docker.sh"
    fi
    exit 0
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 1 Complete!                                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next: ./02-install-docker.sh"
echo ""
