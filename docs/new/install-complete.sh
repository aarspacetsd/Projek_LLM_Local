#!/bin/bash

# =============================================================================
# 🤖 LOCAL AI CODING ASSISTANT - COMPLETE INSTALLER
# =============================================================================
# Target: Ubuntu 24.04 dengan NVIDIA GPU (RTX 3060 12GB)
# Components: Ollama, Open WebUI, LobeChat, Models, Tools
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Colors & Variables
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/local-ai"
OLLAMA_DATA="/var/lib/docker/ollama-data"
LOG_FILE="$INSTALL_DIR/install.log"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     🤖 LOCAL AI CODING ASSISTANT - COMPLETE INSTALLER            ║"
    echo "║                                                                   ║"
    echo "║     Components:                                                   ║"
    echo "║     • Ollama (LLM Engine)                                        ║"
    echo "║     • Open WebUI (Chat Interface)                                ║"
    echo "║     • LobeChat (Alternative UI with Artifacts)                   ║"
    echo "║     • Qwen2.5-Coder, DeepSeek-R1, CodeLlama                     ║"
    echo "║     • Aider (Terminal Git Integration)                           ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${CYAN}    ℹ ${NC} $1"
}

print_success() {
    echo -e "${GREEN}    ✓ ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}    ⚠ ${NC} $1"
}

print_error() {
    echo -e "${RED}    ✗ ${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Jangan jalankan script ini sebagai root!"
        print_info "Jalankan dengan: ./install-complete.sh"
        exit 1
    fi
}

check_ubuntu() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_warning "Script ini dioptimalkan untuk Ubuntu. OS Anda: $ID"
            read -p "Lanjutkan? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "Ubuntu $VERSION_ID detected"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Step 1: System Update & Prerequisites
# -----------------------------------------------------------------------------
install_prerequisites() {
    print_step "Step 1/8: Installing Prerequisites"
    
    print_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    
    print_info "Installing required packages..."
    sudo apt install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        python3-venv \
        jq \
        htop \
        nvtop \
        tmux
    
    print_success "Prerequisites installed"
}

# -----------------------------------------------------------------------------
# Step 2: NVIDIA Driver
# -----------------------------------------------------------------------------
install_nvidia_driver() {
    print_step "Step 2/8: Checking/Installing NVIDIA Driver"
    
    if command -v nvidia-smi &> /dev/null; then
        print_success "NVIDIA Driver already installed:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | sed 's/^/    /'
    else
        print_info "Installing NVIDIA Driver..."
        sudo add-apt-repository -y ppa:graphics-drivers/ppa
        sudo apt update
        sudo ubuntu-drivers autoinstall
        
        print_warning "NVIDIA Driver installed. REBOOT REQUIRED!"
        print_info "After reboot, run this script again."
        
        read -p "Reboot now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
        exit 0
    fi
}

# -----------------------------------------------------------------------------
# Step 3: Docker
# -----------------------------------------------------------------------------
install_docker() {
    print_step "Step 3/8: Installing Docker"
    
    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version | cut -d' ' -f3)"
    else
        print_info "Removing old Docker versions..."
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        print_info "Adding Docker repository..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        print_info "Installing Docker..."
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        print_info "Adding user to docker group..."
        sudo usermod -aG docker $USER
        
        print_success "Docker installed"
        print_warning "You need to logout/login for docker group to take effect"
    fi
}

# -----------------------------------------------------------------------------
# Step 4: NVIDIA Container Toolkit
# -----------------------------------------------------------------------------
install_nvidia_container_toolkit() {
    print_step "Step 4/8: Installing NVIDIA Container Toolkit"
    
    if dpkg -l | grep -q nvidia-container-toolkit; then
        print_success "NVIDIA Container Toolkit already installed"
    else
        print_info "Adding NVIDIA Container Toolkit repository..."
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
            sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        print_info "Installing NVIDIA Container Toolkit..."
        sudo apt update
        sudo apt install -y nvidia-container-toolkit
        
        print_info "Configuring Docker runtime..."
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
        
        print_success "NVIDIA Container Toolkit installed"
    fi
    
    # Test GPU in Docker
    print_info "Testing GPU in Docker..."
    if sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &>/dev/null; then
        print_success "GPU accessible in Docker!"
    else
        print_warning "GPU not detected in Docker. May need reboot."
    fi
}

# -----------------------------------------------------------------------------
# Step 5: Ollama with Proper Storage Configuration
# -----------------------------------------------------------------------------
install_ollama() {
    print_step "Step 5/8: Installing & Configuring Ollama"
    
    # Install Ollama
    if command -v ollama &> /dev/null; then
        print_success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
    else
        print_info "Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        print_success "Ollama installed"
    fi
    
    # Setup storage in Docker partition (larger space)
    print_info "Configuring Ollama storage..."
    
    # Create ollama data directory in docker partition
    sudo mkdir -p "$OLLAMA_DATA"
    sudo chown -R ollama:ollama "$OLLAMA_DATA"
    sudo chmod -R 755 "$OLLAMA_DATA"
    
    # Fix parent directory permission
    sudo chmod o+x /var/lib/docker
    
    # Create symlinks
    sudo rm -rf /usr/share/ollama/.ollama 2>/dev/null || true
    sudo ln -sf "$OLLAMA_DATA" /usr/share/ollama/.ollama
    sudo chown -h ollama:ollama /usr/share/ollama/.ollama
    
    rm -rf ~/.ollama 2>/dev/null || true
    ln -sf "$OLLAMA_DATA" ~/.ollama
    
    # Configure Ollama service
    print_info "Configuring Ollama service..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_MODELS=$OLLAMA_DATA/models"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_ORIGINS=*"
EOF
    
    # Start Ollama
    sudo systemctl daemon-reload
    sudo systemctl enable ollama
    sudo systemctl restart ollama
    
    # Wait for Ollama to be ready
    print_info "Waiting for Ollama to start..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            print_success "Ollama is running on http://localhost:11434"
            break
        fi
        sleep 2
    done
}

# -----------------------------------------------------------------------------
# Step 6: Download AI Models
# -----------------------------------------------------------------------------
download_models() {
    print_step "Step 6/8: Downloading AI Models"
    
    print_warning "This will download ~25GB of models. May take 30-60 minutes."
    echo ""
    
    # Model 1: Qwen2.5-Coder-14B (Main coding model)
    print_info "[1/5] Downloading Qwen2.5-Coder-14B (~9GB)..."
    ollama pull qwen2.5-coder:14b
    print_success "Qwen2.5-Coder-14B downloaded"
    
    # Model 2: Qwen2.5-Coder-7B (Fast model)
    print_info "[2/5] Downloading Qwen2.5-Coder-7B (~5GB)..."
    ollama pull qwen2.5-coder:7b
    print_success "Qwen2.5-Coder-7B downloaded"
    
    # Model 3: DeepSeek-R1 (Reasoning)
    print_info "[3/5] Downloading DeepSeek-R1:14B (~9GB)..."
    ollama pull deepseek-r1:14b
    print_success "DeepSeek-R1:14B downloaded"
    
    # Model 4: Embedding model for RAG
    print_info "[4/5] Downloading nomic-embed-text (~274MB)..."
    ollama pull nomic-embed-text
    print_success "nomic-embed-text downloaded"
    
    # Model 5: Create custom coding assistant
    print_info "[5/5] Creating custom coding-assistant model..."
    
    cat > /tmp/Modelfile-coding << 'MODELFILE'
FROM qwen2.5-coder:14b

SYSTEM """Anda adalah asisten coding AI senior yang sangat ahli. Anda membantu developer dengan:

🔹 Menulis kode yang bersih, efisien, dan well-documented
🔹 Debugging dan troubleshooting dengan analisis detail
🔹 Code review untuk bugs, security, dan performance
🔹 Menjelaskan konsep kompleks dengan bahasa sederhana

Response Guidelines:
- Gunakan code blocks dengan syntax highlighting
- Struktur response dengan jelas
- Berikan penjelasan untuk setiap bagian penting
- Respons dalam bahasa yang sama dengan pertanyaan user (Indonesia/English)"""

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
MODELFILE
    
    ollama create coding-assistant -f /tmp/Modelfile-coding
    rm /tmp/Modelfile-coding
    print_success "Custom coding-assistant model created"
    
    echo ""
    print_info "Installed models:"
    ollama list
}

# -----------------------------------------------------------------------------
# Step 7: Setup Docker Compose Services
# -----------------------------------------------------------------------------
setup_services() {
    print_step "Step 7/8: Setting up Web UI Services"
    
    # Create directory structure
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/uploads"
    mkdir -p "$INSTALL_DIR/data"
    cd "$INSTALL_DIR"
    
    # Create Docker Compose file with all services
    print_info "Creating docker-compose.yml..."
    
    cat > docker-compose.yml << 'COMPOSE'
services:
  # ==========================================================================
  # Open WebUI - Main Chat Interface (like Claude/ChatGPT)
  # ==========================================================================
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui-data:/app/backend/data
      - ./uploads:/app/backend/data/uploads
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_AUTH=false
      - ENABLE_RAG_WEB_SEARCH=true
      - RAG_EMBEDDING_MODEL=nomic-embed-text
      - RAG_EMBEDDING_MODEL_AUTO_UPDATE=true
      - CHUNK_SIZE=1500
      - CHUNK_OVERLAP=100
      - WEBUI_NAME=Local AI Coding Assistant
      - DEFAULT_MODELS=coding-assistant,qwen2.5-coder:14b,deepseek-r1:14b
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ==========================================================================
  # LobeChat - Alternative UI with Artifacts support
  # ==========================================================================
  lobe-chat:
    image: lobehub/lobe-chat:latest
    container_name: lobe-chat
    ports:
      - "3210:3210"
    environment:
      - OLLAMA_PROXY_URL=http://host.docker.internal:11434/v1
      - ACCESS_CODE=localai123
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  # ==========================================================================
  # SearXNG - Web Search Engine (optional)
  # ==========================================================================
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    ports:
      - "8888:8080"
    volumes:
      - searxng-data:/etc/searxng
    environment:
      - SEARXNG_BASE_URL=http://localhost:8888/
    restart: unless-stopped

volumes:
  open-webui-data:
  searxng-data:
COMPOSE
    
    print_success "docker-compose.yml created"
    
    # Start services
    print_info "Starting services..."
    docker compose up -d
    
    # Wait for services
    print_info "Waiting for services to be ready..."
    sleep 15
    
    # Check services
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Open WebUI is running"
    else
        print_warning "Open WebUI may still be starting..."
    fi
    
    if curl -s http://localhost:3210 > /dev/null 2>&1; then
        print_success "LobeChat is running"
    else
        print_warning "LobeChat may still be starting..."
    fi
}

# -----------------------------------------------------------------------------
# Step 8: Install Additional Tools & Create Helper Scripts
# -----------------------------------------------------------------------------
install_tools_and_helpers() {
    print_step "Step 8/8: Installing Tools & Creating Helper Scripts"
    
    # Install Aider
    print_info "Installing Aider (Git-integrated AI coding)..."
    pip install aider-chat --break-system-packages 2>/dev/null || pip install aider-chat
    print_success "Aider installed"
    
    # Create helper scripts
    print_info "Creating helper scripts..."
    
    # Start script
    cat > "$INSTALL_DIR/start.sh" << 'SCRIPT'
#!/bin/bash
echo "🚀 Starting Local AI Services..."
echo ""

# Start Ollama
echo "Starting Ollama..."
sudo systemctl start ollama
sleep 3

# Start Docker services
echo "Starting Docker services..."
cd ~/local-ai
docker compose up -d

# Wait and check
sleep 5

echo ""
echo "✅ Services Started!"
echo ""
echo "📍 Access URLs:"
echo "   Open WebUI:  http://localhost:3000"
echo "   LobeChat:    http://localhost:3210"
echo "   SearXNG:     http://localhost:8888"
echo "   Ollama API:  http://localhost:11434"
echo ""
SCRIPT
    chmod +x "$INSTALL_DIR/start.sh"
    
    # Stop script
    cat > "$INSTALL_DIR/stop.sh" << 'SCRIPT'
#!/bin/bash
echo "🛑 Stopping Local AI Services..."
echo ""

cd ~/local-ai
docker compose down
sudo systemctl stop ollama

echo "✅ All services stopped"
SCRIPT
    chmod +x "$INSTALL_DIR/stop.sh"
    
    # Status script
    cat > "$INSTALL_DIR/status.sh" << 'SCRIPT'
#!/bin/bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              📊 LOCAL AI STATUS                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Ollama
echo "🦙 Ollama:"
if systemctl is-active --quiet ollama; then
    echo "   Status: ✅ Running"
    echo "   URL: http://localhost:11434"
    echo "   Loaded models:"
    ollama ps 2>/dev/null | sed 's/^/      /' || echo "      None"
else
    echo "   Status: ❌ Stopped"
fi

echo ""

# Open WebUI
echo "🖥️  Open WebUI:"
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "   Status: ✅ Running"
    echo "   URL: http://localhost:3000"
else
    echo "   Status: ❌ Stopped"
fi

echo ""

# LobeChat
echo "🎨 LobeChat:"
if curl -s http://localhost:3210 > /dev/null 2>&1; then
    echo "   Status: ✅ Running"
    echo "   URL: http://localhost:3210"
else
    echo "   Status: ❌ Stopped"
fi

echo ""

# GPU
echo "🎮 GPU:"
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>/dev/null | \
    awk -F', ' '{printf "   %s\n   GPU: %s | Memory: %s / %s | Temp: %s\n", $1, $2, $3, $4, $5}' || \
    echo "   Not available"

echo ""

# Disk
echo "💾 Storage:"
df -h / /var/lib/docker 2>/dev/null | tail -n +2 | while read line; do
    echo "   $line"
done

echo ""

# Docker containers
echo "🐳 Docker Containers:"
docker ps --format "   {{.Names}}: {{.Status}}" 2>/dev/null || echo "   Docker not running"

echo ""
echo "═══════════════════════════════════════════════════════════════"
SCRIPT
    chmod +x "$INSTALL_DIR/status.sh"
    
    # Update script
    cat > "$INSTALL_DIR/update.sh" << 'SCRIPT'
#!/bin/bash
echo "🔄 Updating Local AI Components..."
echo ""

# Update Ollama
echo "📦 Updating Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Update Docker images
echo "🐳 Updating Docker images..."
cd ~/local-ai
docker compose pull
docker compose up -d

# Update Aider
echo "🔧 Updating Aider..."
pip install --upgrade aider-chat --break-system-packages 2>/dev/null || pip install --upgrade aider-chat

echo ""
echo "✅ Update complete!"
SCRIPT
    chmod +x "$INSTALL_DIR/update.sh"
    
    # GPU monitor script
    cat > "$INSTALL_DIR/gpu-watch.sh" << 'SCRIPT'
#!/bin/bash
watch -n 1 nvidia-smi
SCRIPT
    chmod +x "$INSTALL_DIR/gpu-watch.sh"
    
    # Logs script
    cat > "$INSTALL_DIR/logs.sh" << 'SCRIPT'
#!/bin/bash
SERVICE=${1:-open-webui}
echo "📋 Showing logs for: $SERVICE"
echo "   (Press Ctrl+C to exit)"
echo ""
docker logs -f $SERVICE
SCRIPT
    chmod +x "$INSTALL_DIR/logs.sh"
    
    # Add aliases to bashrc
    print_info "Adding aliases to .bashrc..."
    
    cat >> ~/.bashrc << 'ALIASES'

# =============================================================================
# Local AI Aliases
# =============================================================================
alias ai-start='~/local-ai/start.sh'
alias ai-stop='~/local-ai/stop.sh'
alias ai-status='~/local-ai/status.sh'
alias ai-update='~/local-ai/update.sh'
alias ai-logs='~/local-ai/logs.sh'
alias ai-gpu='~/local-ai/gpu-watch.sh'

# Aider aliases
alias aider-qwen='aider --model ollama/qwen2.5-coder:14b'
alias aider-deepseek='aider --model ollama/deepseek-r1:14b'
alias aider-fast='aider --model ollama/qwen2.5-coder:7b'

# Quick ollama commands
alias ai-models='ollama list'
alias ai-running='ollama ps'
ALIASES
    
    print_success "Helper scripts and aliases created"
}

# -----------------------------------------------------------------------------
# Print Summary
# -----------------------------------------------------------------------------
print_summary() {
    # Get IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}║              🎉 INSTALLATION COMPLETE!                            ║${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}📍 Access URLs:${NC}"
    echo "   Open WebUI:  http://$IP_ADDR:3000  (Main chat interface)"
    echo "   LobeChat:    http://$IP_ADDR:3210  (Alternative UI + Artifacts)"
    echo "   SearXNG:     http://$IP_ADDR:8888  (Web search)"
    echo "   Ollama API:  http://$IP_ADDR:11434"
    echo ""
    echo -e "${GREEN}📦 Installed Models:${NC}"
    ollama list 2>/dev/null | sed 's/^/   /'
    echo ""
    echo -e "${GREEN}🛠️  Quick Commands:${NC}"
    echo "   ai-start    - Start all services"
    echo "   ai-stop     - Stop all services"
    echo "   ai-status   - Check status"
    echo "   ai-update   - Update components"
    echo "   ai-gpu      - Monitor GPU"
    echo "   ai-logs     - View logs"
    echo ""
    echo -e "${GREEN}🔧 Aider Commands (Terminal AI):${NC}"
    echo "   aider-qwen      - Start Aider with Qwen (main)"
    echo "   aider-deepseek  - Start Aider with DeepSeek (reasoning)"
    echo "   aider-fast      - Start Aider with Qwen 7B (fast)"
    echo ""
    echo -e "${GREEN}📁 Installation Directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${YELLOW}⚠️  Notes:${NC}"
    echo "   • Run 'source ~/.bashrc' to load aliases"
    echo "   • LobeChat access code: localai123"
    echo "   • For VS Code: Install 'Continue' extension"
    echo ""
    echo -e "${GREEN}🚀 Getting Started:${NC}"
    echo "   1. Open browser: http://$IP_ADDR:3000"
    echo "   2. Select model: coding-assistant or qwen2.5-coder:14b"
    echo "   3. Start coding!"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    print_banner
    
    echo -e "${YELLOW}This script will install:${NC}"
    echo "  • NVIDIA Driver & Container Toolkit"
    echo "  • Docker & Docker Compose"
    echo "  • Ollama (LLM Engine)"
    echo "  • Open WebUI + LobeChat (Web Interfaces)"
    echo "  • AI Models (~25GB download)"
    echo "  • Aider (Terminal AI tool)"
    echo ""
    
    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Run installation steps
    check_root
    check_ubuntu
    install_prerequisites
    install_nvidia_driver
    install_docker
    install_nvidia_container_toolkit
    install_ollama
    download_models
    setup_services
    install_tools_and_helpers
    
    print_summary
    
    # Reload bashrc
    echo ""
    echo "Run this to load aliases:"
    echo "  source ~/.bashrc"
    echo ""
}

# Run main
main "$@"
