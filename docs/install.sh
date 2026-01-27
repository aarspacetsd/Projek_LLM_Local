#!/bin/bash

# =============================================================================
# 🤖 LOCAL AI CODING ASSISTANT - INSTALLER
# =============================================================================
# Target: Ubuntu 22.04/24.04 dengan NVIDIA GPU
# Hardware: RTX 3060 12GB + 64GB RAM
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Warna untuk output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Konfigurasi
# -----------------------------------------------------------------------------
INSTALL_DIR="$HOME/local-ai"
LOG_FILE="$INSTALL_DIR/install.log"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         🤖 LOCAL AI CODING ASSISTANT INSTALLER                ║"
    echo "║                                                               ║"
    echo "║         Ollama + Open WebUI + Qwen2.5-Coder                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[$(date '+%H:%M:%S')]${NC} ${GREEN}==>${NC} $1"
}

print_info() {
    echo -e "${CYAN}    ℹ${NC}  $1"
}

print_warning() {
    echo -e "${YELLOW}    ⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}    ✗${NC}  $1"
}

print_success() {
    echo -e "${GREEN}    ✓${NC}  $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Jangan jalankan script ini sebagai root!"
        print_info "Jalankan dengan: ./install.sh"
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
        fi
    fi
}

# -----------------------------------------------------------------------------
# Step 1: Prerequisites
# -----------------------------------------------------------------------------
install_prerequisites() {
    print_step "Menginstall prerequisites..."
    
    sudo apt update
    sudo apt install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    print_success "Prerequisites terinstall"
}

# -----------------------------------------------------------------------------
# Step 2: NVIDIA Driver
# -----------------------------------------------------------------------------
check_nvidia_driver() {
    print_step "Mengecek NVIDIA Driver..."
    
    if command -v nvidia-smi &> /dev/null; then
        print_success "NVIDIA Driver sudah terinstall:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | while read line; do
            print_info "$line"
        done
        return 0
    else
        return 1
    fi
}

install_nvidia_driver() {
    if check_nvidia_driver; then
        return 0
    fi
    
    print_step "Menginstall NVIDIA Driver..."
    
    # Add NVIDIA repository
    sudo add-apt-repository -y ppa:graphics-drivers/ppa
    sudo apt update
    
    # Install recommended driver
    print_info "Menginstall driver yang direkomendasikan..."
    sudo ubuntu-drivers autoinstall
    
    print_warning "NVIDIA Driver terinstall. REBOOT DIPERLUKAN!"
    print_info "Setelah reboot, jalankan script ini lagi."
    
    read -p "Reboot sekarang? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
    exit 0
}

# -----------------------------------------------------------------------------
# Step 3: Docker
# -----------------------------------------------------------------------------
install_docker() {
    print_step "Menginstall Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker sudah terinstall: $(docker --version)"
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
        
        print_success "Docker terinstall"
        print_warning "Anda perlu logout/login agar docker group aktif"
    fi
}

# -----------------------------------------------------------------------------
# Step 4: NVIDIA Container Toolkit
# -----------------------------------------------------------------------------
install_nvidia_container_toolkit() {
    print_step "Menginstall NVIDIA Container Toolkit..."
    
    if dpkg -l | grep -q nvidia-container-toolkit; then
        print_success "NVIDIA Container Toolkit sudah terinstall"
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
        
        print_success "NVIDIA Container Toolkit terinstall"
    fi
    
    # Test GPU in Docker
    print_info "Testing GPU di Docker..."
    if sudo docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &>/dev/null; then
        print_success "GPU berhasil terdeteksi di Docker!"
    else
        print_warning "GPU belum terdeteksi di Docker. Mungkin perlu reboot."
    fi
}

# -----------------------------------------------------------------------------
# Step 5: Ollama
# -----------------------------------------------------------------------------
install_ollama() {
    print_step "Menginstall Ollama..."
    
    if command -v ollama &> /dev/null; then
        print_success "Ollama sudah terinstall: $(ollama --version)"
    else
        curl -fsSL https://ollama.com/install.sh | sh
        print_success "Ollama terinstall"
    fi
    
    # Enable and start service
    sudo systemctl enable ollama
    sudo systemctl start ollama
    
    # Wait for Ollama to be ready
    print_info "Menunggu Ollama siap..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            print_success "Ollama berjalan di http://localhost:11434"
            break
        fi
        sleep 2
    done
}

# -----------------------------------------------------------------------------
# Step 6: Setup Directory & Docker Compose
# -----------------------------------------------------------------------------
setup_project() {
    print_step "Menyiapkan direktori project..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/uploads"
    cd "$INSTALL_DIR"
    
    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
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
      - CHUNK_SIZE=1500
      - CHUNK_OVERLAP=100
      - WEBUI_NAME=Local Coding AI
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

volumes:
  open-webui-data:
EOF
    
    print_success "docker-compose.yml dibuat di $INSTALL_DIR"
}

# -----------------------------------------------------------------------------
# Step 7: Create Modelfile
# -----------------------------------------------------------------------------
create_modelfile() {
    print_step "Membuat Modelfile untuk coding assistant..."
    
    cat > "$INSTALL_DIR/Modelfile-coding" << 'EOF'
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
- Respons dalam bahasa yang sama dengan pertanyaan user"""

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
EOF
    
    print_success "Modelfile dibuat"
}

# -----------------------------------------------------------------------------
# Step 8: Download Models
# -----------------------------------------------------------------------------
download_models() {
    print_step "Mendownload AI Models..."
    print_info "Ini bisa memakan waktu 10-30 menit tergantung koneksi internet"
    echo ""
    
    # Main coding model
    print_info "Downloading Qwen2.5-Coder-14B (~9GB)..."
    ollama pull qwen2.5-coder:14b
    print_success "Qwen2.5-Coder-14B selesai"
    
    # Embedding model for RAG
    print_info "Downloading nomic-embed-text (~274MB)..."
    ollama pull nomic-embed-text
    print_success "nomic-embed-text selesai"
    
    # Smaller model for quick tasks
    print_info "Downloading Qwen2.5-Coder-7B (~4.7GB)..."
    ollama pull qwen2.5-coder:7b
    print_success "Qwen2.5-Coder-7B selesai"
    
    # Create custom model
    print_info "Membuat custom coding-assistant model..."
    ollama create coding-assistant -f "$INSTALL_DIR/Modelfile-coding"
    print_success "Custom model 'coding-assistant' dibuat"
}

# -----------------------------------------------------------------------------
# Step 9: Start Open WebUI
# -----------------------------------------------------------------------------
start_services() {
    print_step "Menjalankan Open WebUI..."
    
    cd "$INSTALL_DIR"
    docker compose up -d
    
    # Wait for service
    print_info "Menunggu Open WebUI siap..."
    for i in {1..60}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            print_success "Open WebUI berjalan!"
            break
        fi
        sleep 2
    done
}

# -----------------------------------------------------------------------------
# Step 10: Create helper scripts
# -----------------------------------------------------------------------------
create_helper_scripts() {
    print_step "Membuat helper scripts..."
    
    # Start script
    cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting Local AI..."
sudo systemctl start ollama
cd ~/local-ai && docker compose up -d
echo "✅ Services started!"
echo "   Open WebUI: http://localhost:3000"
echo "   Ollama API: http://localhost:11434"
EOF
    chmod +x "$INSTALL_DIR/start.sh"
    
    # Stop script
    cat > "$INSTALL_DIR/stop.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stopping Local AI..."
cd ~/local-ai && docker compose down
sudo systemctl stop ollama
echo "✅ Services stopped!"
EOF
    chmod +x "$INSTALL_DIR/stop.sh"
    
    # Status script
    cat > "$INSTALL_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "📊 Local AI Status"
echo "=================="
echo ""
echo "🦙 Ollama:"
systemctl is-active ollama && echo "   Status: Running" || echo "   Status: Stopped"
ollama ps 2>/dev/null || echo "   No models loaded"
echo ""
echo "🖥️  Open WebUI:"
docker ps --filter "name=open-webui" --format "   Status: {{.Status}}"
echo ""
echo "🎮 GPU:"
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "   Not available"
echo ""
echo "📦 Installed Models:"
ollama list 2>/dev/null || echo "   Cannot retrieve"
EOF
    chmod +x "$INSTALL_DIR/status.sh"
    
    # Update script
    cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
echo "🔄 Updating Local AI components..."

echo "Updating Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "Updating Open WebUI..."
cd ~/local-ai
docker compose pull
docker compose up -d

echo "✅ Update complete!"
EOF
    chmod +x "$INSTALL_DIR/update.sh"
    
    print_success "Helper scripts dibuat di $INSTALL_DIR"
}

# -----------------------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------------------
print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🎉 INSTALASI SELESAI!                            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}📍 Access URLs:${NC}"
    echo "   Open WebUI:  http://localhost:3000"
    echo "   Ollama API:  http://localhost:11434"
    echo ""
    echo -e "${GREEN}📦 Models Terinstall:${NC}"
    ollama list
    echo ""
    echo -e "${GREEN}🛠️  Helper Scripts:${NC}"
    echo "   $INSTALL_DIR/start.sh   - Start semua services"
    echo "   $INSTALL_DIR/stop.sh    - Stop semua services"
    echo "   $INSTALL_DIR/status.sh  - Cek status"
    echo "   $INSTALL_DIR/update.sh  - Update components"
    echo ""
    echo -e "${GREEN}🚀 Quick Start:${NC}"
    echo "   1. Buka browser: http://localhost:3000"
    echo "   2. Pilih model: coding-assistant atau qwen2.5-coder:14b"
    echo "   3. Mulai coding!"
    echo ""
    echo -e "${YELLOW}⚠️  Jika baru install Docker, logout dan login kembali${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    print_banner
    
    check_root
    check_ubuntu
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Run installation steps
    install_prerequisites
    install_nvidia_driver
    install_docker
    install_nvidia_container_toolkit
    install_ollama
    setup_project
    create_modelfile
    download_models
    start_services
    create_helper_scripts
    
    print_summary
}

# Run main function
main "$@"
