#!/bin/bash

# =============================================================================
# 🗑️ UNINSTALL LOCAL AI
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🗑️  Uninstall Local AI Coding Assistant                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}This will remove:${NC}"
echo "  • Docker containers (Open WebUI, LobeChat, SearXNG)"
echo "  • Docker volumes (conversation history)"
echo "  • Ollama and all models"
echo "  • Helper scripts and aliases"
echo ""
echo -e "${RED}⚠️  All conversation history will be LOST!${NC}"
echo ""

read -p "Are you sure? Type 'yes' to confirm: " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# Stop services
echo "🛑 Stopping services..."
cd ~/local-ai 2>/dev/null && docker compose down 2>/dev/null || true
sudo systemctl stop ollama 2>/dev/null || true

# Remove Docker containers and volumes
echo "🐳 Removing Docker containers and volumes..."
docker rm -f open-webui lobe-chat searxng lobe-postgres 2>/dev/null || true
docker volume rm local-ai_open-webui-data local-ai_searxng-data local-ai_lobe-postgres-data 2>/dev/null || true
docker image rm ghcr.io/open-webui/open-webui:main lobehub/lobe-chat:latest searxng/searxng:latest 2>/dev/null || true

# Remove Ollama
read -p "Remove Ollama and all models? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🦙 Removing Ollama..."
    sudo systemctl disable ollama 2>/dev/null || true
    sudo rm -f /etc/systemd/system/ollama.service
    sudo rm -rf /etc/systemd/system/ollama.service.d
    sudo rm -f /usr/local/bin/ollama
    sudo rm -rf /usr/share/ollama
    sudo rm -rf /var/lib/docker/ollama-data
    rm -rf ~/.ollama
    sudo userdel ollama 2>/dev/null || true
    sudo groupdel ollama 2>/dev/null || true
    sudo systemctl daemon-reload
    echo "  ✓ Ollama removed"
fi

# Remove project directory
read -p "Remove ~/local-ai directory? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/local-ai
    rm -rf ~/github-imports
    echo "  ✓ Directory removed"
fi

# Remove Aider
read -p "Remove Aider? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pip uninstall aider-chat -y 2>/dev/null || true
    echo "  ✓ Aider removed"
fi

# Remove aliases from bashrc
echo "📝 Cleaning .bashrc..."
sed -i '/# Local AI Aliases/,/# =*$/d' ~/.bashrc 2>/dev/null || true
sed -i '/alias ai-/d' ~/.bashrc 2>/dev/null || true
sed -i '/alias aider-/d' ~/.bashrc 2>/dev/null || true
sed -i '/LOCAL_AI_DIR/d' ~/.bashrc 2>/dev/null || true

# Remove Docker (optional)
read -p "Remove Docker completely? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🐳 Removing Docker..."
    sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    echo "  ✓ Docker removed"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Uninstall Complete                                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Run 'source ~/.bashrc' to reload shell configuration."
echo ""
