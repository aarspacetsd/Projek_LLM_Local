#!/bin/bash

# =============================================================================
# 🖥️ STEP 5: SETUP WEB UI (Open WebUI + LobeChat)
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
print_info() { echo -e "${CYAN}  ℹ${NC} $1"; }

INSTALL_DIR="$HOME/local-ai"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🖥️ Step 5: Setup Web UI Services                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Create Directory
# -----------------------------------------------------------------------------
print_step "Creating project directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/uploads"
mkdir -p "$INSTALL_DIR/data"
cd "$INSTALL_DIR"
print_success "Directory created: $INSTALL_DIR"

# -----------------------------------------------------------------------------
# Create Docker Compose
# -----------------------------------------------------------------------------
print_step "Creating docker-compose.yml..."

cat > docker-compose.yml << 'COMPOSE'
# =============================================================================
# Local AI Coding Assistant - Docker Compose
# =============================================================================

services:
  # ---------------------------------------------------------------------------
  # Open WebUI - Main Chat Interface
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # LobeChat - Alternative UI with Artifacts
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # SearXNG - Web Search (Optional)
  # ---------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Pull Images
# -----------------------------------------------------------------------------
print_step "Pulling Docker images (this may take a few minutes)..."
docker compose pull
print_success "Images pulled"

# -----------------------------------------------------------------------------
# Start Services
# -----------------------------------------------------------------------------
print_step "Starting services..."
docker compose up -d

# Wait for services
print_info "Waiting for services to start..."
sleep 20

# -----------------------------------------------------------------------------
# Verify Services
# -----------------------------------------------------------------------------
print_step "Verifying services..."

echo ""
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Open WebUI: http://localhost:3000 ✅"
else
    print_warning "Open WebUI: Starting... (may take 1-2 minutes first time)"
fi

if curl -s http://localhost:3210 > /dev/null 2>&1; then
    print_success "LobeChat: http://localhost:3210 ✅"
else
    print_warning "LobeChat: Starting..."
fi

if curl -s http://localhost:8888 > /dev/null 2>&1; then
    print_success "SearXNG: http://localhost:8888 ✅"
else
    print_warning "SearXNG: Starting..."
fi

# -----------------------------------------------------------------------------
# Docker Status
# -----------------------------------------------------------------------------
echo ""
print_step "Docker containers status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 5 Complete - Web UI Services Running!                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Access URLs:"
echo "   Open WebUI:  http://localhost:3000"
echo "   LobeChat:    http://localhost:3210  (access code: localai123)"
echo "   SearXNG:     http://localhost:8888"
echo ""
echo "📝 LobeChat Setup:"
echo "   1. Go to Settings → Language Model → Ollama"
echo "   2. Set URL: http://$(hostname -I | awk '{print $1}'):11434"
echo "   3. Enable and select models"
echo ""
echo "Next: ./06-setup-tools.sh"
echo ""
