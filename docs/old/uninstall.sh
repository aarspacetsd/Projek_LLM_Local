#!/bin/bash

# =============================================================================
# 🗑️ UNINSTALL LOCAL AI
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  🗑️ Uninstall Local AI                 ║"
echo "╚════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}Ini akan menghapus:${NC}"
echo "  - Open WebUI container dan data"
echo "  - Ollama dan semua models"
echo "  - Docker images terkait"
echo ""
echo -e "${RED}Data conversation akan HILANG!${NC}"
echo ""

read -p "Yakin ingin melanjutkan? (yes/no) " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Dibatalkan."
    exit 0
fi

echo ""

# Stop services
echo "🛑 Stopping services..."
cd ~/local-ai 2>/dev/null && docker compose down 2>/dev/null || true
sudo systemctl stop ollama 2>/dev/null || true

# Remove Open WebUI
echo "🗑️ Removing Open WebUI..."
docker rm -f open-webui 2>/dev/null || true
docker volume rm local-ai_open-webui-data 2>/dev/null || true
docker image rm ghcr.io/open-webui/open-webui:main 2>/dev/null || true

# Remove Ollama
read -p "Hapus Ollama juga? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️ Removing Ollama..."
    sudo systemctl disable ollama 2>/dev/null || true
    sudo rm /etc/systemd/system/ollama.service 2>/dev/null || true
    sudo rm -rf /usr/local/bin/ollama 2>/dev/null || true
    sudo rm -rf /usr/share/ollama 2>/dev/null || true
    rm -rf ~/.ollama 2>/dev/null || true
    echo "  ✓ Ollama removed"
fi

# Remove project directory
read -p "Hapus direktori ~/local-ai? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/local-ai
    echo "  ✓ Directory removed"
fi

# Remove Docker (optional)
read -p "Hapus Docker juga? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️ Removing Docker..."
    sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo rm -rf /var/lib/docker
    echo "  ✓ Docker removed"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Uninstall Complete                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
