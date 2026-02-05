#!/bin/bash

# =============================================================================
# 🦙 INSTALL OLLAMA
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_info() { echo -e "${BLUE}  ℹ${NC} $1"; }

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  🦙 Installing Ollama                  ║"
echo "╚════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Install Ollama
# -----------------------------------------------------------------------------
print_step "Installing Ollama..."

if command -v ollama &> /dev/null; then
    print_success "Ollama sudah terinstall"
    ollama --version
else
    curl -fsSL https://ollama.com/install.sh | sh
    print_success "Ollama terinstall"
fi

# -----------------------------------------------------------------------------
# Start Ollama service
# -----------------------------------------------------------------------------
print_step "Starting Ollama service..."

sudo systemctl enable ollama
sudo systemctl start ollama

# Wait for Ollama
print_info "Menunggu Ollama siap..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        print_success "Ollama berjalan!"
        break
    fi
    sleep 2
done

# -----------------------------------------------------------------------------
# Configure for better performance
# -----------------------------------------------------------------------------
print_step "Configuring Ollama untuk GPU..."

# Create override config
sudo mkdir -p /etc/systemd/system/ollama.service.d/

sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_HOST=0.0.0.0"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

print_success "Ollama configured"

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------
print_step "Verifying installation..."

sleep 3
curl -s http://localhost:11434/api/tags | head -5

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Ollama Installed!                  ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Ollama API: http://localhost:11434"
echo ""
echo "Next step: ./03-download-models.sh"
echo ""
