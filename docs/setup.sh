#!/bin/bash

# =============================================================================
# Setup Script: Local AI Coding Assistant
# For: Ubuntu/Debian with NVIDIA GPU
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "  ✓ $1 installed"
        return 0
    else
        echo -e "  ✗ $1 not found"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
print_step "Running pre-flight checks..."

echo "Checking system requirements:"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Some steps may behave differently."
fi

# Check NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo -e "  ✓ NVIDIA driver detected"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    print_error "NVIDIA driver not found. Please install NVIDIA drivers first."
    echo "Run: sudo apt install nvidia-driver-535"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    print_warning "Docker not installed. Installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo -e "  ✓ Docker installed. You may need to logout/login for group changes."
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    print_warning "Docker Compose not found. Installing..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
fi

# Check NVIDIA Container Toolkit
if ! dpkg -l | grep -q nvidia-container-toolkit; then
    print_warning "NVIDIA Container Toolkit not found. Installing..."
    
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

echo -e "  ✓ All prerequisites satisfied"

# -----------------------------------------------------------------------------
# Setup Directories
# -----------------------------------------------------------------------------
print_step "Setting up directories..."

INSTALL_DIR="$HOME/local-ai"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/uploads"
mkdir -p "$INSTALL_DIR/models"

# Copy files if script is run from the setup directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/Modelfile-coding-assistant" "$INSTALL_DIR/" 2>/dev/null || true
fi

cd "$INSTALL_DIR"
echo "Working directory: $INSTALL_DIR"

# -----------------------------------------------------------------------------
# Start Services
# -----------------------------------------------------------------------------
print_step "Starting Docker services..."

docker compose up -d

echo "Waiting for services to be ready..."
sleep 10

# Check Ollama health
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "  ✓ Ollama is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Ollama failed to start"
        docker logs ollama
        exit 1
    fi
    sleep 2
done

# -----------------------------------------------------------------------------
# Download Models
# -----------------------------------------------------------------------------
print_step "Downloading AI models..."

echo "This may take a while depending on your internet speed..."
echo ""

# Main coding model
echo "Downloading Qwen2.5-Coder-14B (~9GB)..."
docker exec ollama ollama pull qwen2.5-coder:14b

# Embedding model for RAG
echo "Downloading nomic-embed-text (~274MB)..."
docker exec ollama ollama pull nomic-embed-text

# Optional: Smaller/faster model for quick tasks
echo "Downloading Qwen2.5-Coder-7B (~4.7GB)..."
docker exec ollama ollama pull qwen2.5-coder:7b

# -----------------------------------------------------------------------------
# Create Custom Model
# -----------------------------------------------------------------------------
print_step "Creating custom coding assistant model..."

if [ -f "$INSTALL_DIR/Modelfile-coding-assistant" ]; then
    docker exec ollama ollama create coding-assistant -f /root/.ollama/Modelfile-coding-assistant
    echo -e "  ✓ Custom model 'coding-assistant' created"
else
    print_warning "Modelfile not found, skipping custom model creation"
fi

# -----------------------------------------------------------------------------
# Final Status
# -----------------------------------------------------------------------------
print_step "Setup complete!"

echo ""
echo "============================================"
echo "  🎉 Local AI Coding Assistant is ready!"
echo "============================================"
echo ""
echo "  📍 Open WebUI:  http://localhost:3000"
echo "  📍 Ollama API:  http://localhost:11434"
echo ""
echo "  📦 Installed Models:"
docker exec ollama ollama list
echo ""
echo "  🛠️  Useful Commands:"
echo "      - Start:   cd $INSTALL_DIR && docker compose up -d"
echo "      - Stop:    cd $INSTALL_DIR && docker compose down"
echo "      - Logs:    docker logs -f open-webui"
echo "      - GPU:     nvidia-smi"
echo ""
echo "  📖 Documentation: $INSTALL_DIR/README.md"
echo ""
