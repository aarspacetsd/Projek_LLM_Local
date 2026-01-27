#!/bin/bash

# =============================================================================
# 🖥️ INSTALL OPEN WEBUI
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_info() { echo -e "${CYAN}  ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }

INSTALL_DIR="$HOME/local-ai"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  🖥️ Installing Open WebUI              ║"
echo "╚════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Check Docker
# -----------------------------------------------------------------------------
if ! command -v docker &> /dev/null; then
    echo "Error: Docker belum terinstall!"
    echo "Jalankan: ./01-install-prerequisites.sh"
    exit 1
fi

# Check if user can run docker without sudo
if ! docker ps &> /dev/null; then
    print_warning "Docker memerlukan sudo atau user belum di docker group"
    print_info "Mencoba dengan newgrp docker..."
    exec sg docker "$0"
fi

# -----------------------------------------------------------------------------
# Setup Directory
# -----------------------------------------------------------------------------
print_step "Setting up directory..."

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/uploads"
cd "$INSTALL_DIR"

print_success "Directory: $INSTALL_DIR"

# -----------------------------------------------------------------------------
# Create Docker Compose
# -----------------------------------------------------------------------------
print_step "Creating docker-compose.yml..."

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
      # Ollama Connection
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      
      # Disable auth untuk single user
      - WEBUI_AUTH=false
      
      # RAG Settings
      - ENABLE_RAG_WEB_SEARCH=true
      - RAG_EMBEDDING_MODEL=nomic-embed-text
      - RAG_EMBEDDING_MODEL_AUTO_UPDATE=true
      - CHUNK_SIZE=1500
      - CHUNK_OVERLAP=100
      
      # UI Customization
      - WEBUI_NAME=Local Coding AI
      - DEFAULT_MODELS=coding-assistant,qwen2.5-coder:14b
      
      # Performance
      - ENABLE_WEBSOCKET_SUPPORT=true
      
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

volumes:
  open-webui-data:
EOF

print_success "docker-compose.yml created"

# -----------------------------------------------------------------------------
# Pull and Start
# -----------------------------------------------------------------------------
print_step "Pulling Open WebUI image..."
docker compose pull

print_step "Starting Open WebUI..."
docker compose up -d

# -----------------------------------------------------------------------------
# Wait for service
# -----------------------------------------------------------------------------
print_info "Menunggu Open WebUI siap (bisa 1-2 menit pertama kali)..."

for i in {1..90}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Open WebUI berjalan!"
        break
    fi
    if [ $i -eq 90 ]; then
        print_warning "Open WebUI belum merespons. Cek logs dengan: docker logs open-webui"
    fi
    sleep 2
    echo -ne "\r  Waiting... ${i}s"
done
echo ""

# -----------------------------------------------------------------------------
# Create helper scripts
# -----------------------------------------------------------------------------
print_step "Creating helper scripts..."

# Start script
cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting Local AI..."
sudo systemctl start ollama
cd ~/local-ai && docker compose up -d
echo ""
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
echo ""
echo "📊 LOCAL AI STATUS"
echo "══════════════════════════════════════"
echo ""
echo "🦙 Ollama Service:"
if systemctl is-active --quiet ollama; then
    echo "   Status: ✅ Running"
    echo "   URL: http://localhost:11434"
else
    echo "   Status: ❌ Stopped"
fi
echo ""
echo "   Loaded Models:"
ollama ps 2>/dev/null | sed 's/^/   /' || echo "   None"
echo ""
echo "🖥️  Open WebUI:"
if docker ps --filter "name=open-webui" --format "{{.Status}}" | grep -q "Up"; then
    echo "   Status: ✅ Running"
    echo "   URL: http://localhost:3000"
else
    echo "   Status: ❌ Stopped"
fi
echo ""
echo "🎮 GPU:"
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/   /' || echo "   Not available"
echo ""
echo "══════════════════════════════════════"
EOF
chmod +x "$INSTALL_DIR/status.sh"

# Logs script
cat > "$INSTALL_DIR/logs.sh" << 'EOF'
#!/bin/bash
echo "📋 Open WebUI Logs (Ctrl+C to exit):"
docker logs -f open-webui
EOF
chmod +x "$INSTALL_DIR/logs.sh"

# Update script
cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
echo "🔄 Updating Local AI..."
echo ""

echo "📦 Updating Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo ""
echo "🖥️ Updating Open WebUI..."
cd ~/local-ai
docker compose pull
docker compose up -d

echo ""
echo "✅ Update complete!"
EOF
chmod +x "$INSTALL_DIR/update.sh"

print_success "Helper scripts created"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   🎉 INSTALASI SELESAI!                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  🌐 Open WebUI:  http://localhost:3000"
echo "  🦙 Ollama API:  http://localhost:11434"
echo ""
echo "  📁 Install Dir: $INSTALL_DIR"
echo ""
echo "  🛠️  Helper Commands:"
echo "      ./start.sh   - Start all services"
echo "      ./stop.sh    - Stop all services"
echo "      ./status.sh  - Check status"
echo "      ./logs.sh    - View logs"
echo "      ./update.sh  - Update components"
echo ""
echo "  🚀 Quick Start:"
echo "      1. Buka http://localhost:3000 di browser"
echo "      2. Pilih model: coding-assistant"
echo "      3. Mulai coding!"
echo ""
