#!/bin/bash

# =============================================================================
# 🦙 STEP 3: OLLAMA WITH FULL STORAGE PROTECTION
# =============================================================================
# Pencegahan disk penuh:
# ✅ Ollama models di partisi besar (/var/lib/docker)
# ✅ Swap file dipindahkan/dikecilkan
# ✅ Journal size limited
# ✅ Auto-cleanup script
# ✅ Disk space monitoring
# ✅ Safe model download dengan cek space
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
print_info() { echo -e "${BLUE}  ℹ${NC} $1"; }

# Configuration
OLLAMA_DATA="/var/lib/docker/ollama-data"
MIN_SPACE_GB=50
SWAP_SIZE="2G"
JOURNAL_MAX="500M"
INSTALL_DIR="$HOME/local-ai"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🦙 Step 3: Ollama Installation & Storage Protection           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Check Disk Space
# =============================================================================
print_step "Checking disk space..."

echo ""
df -h | grep -E "Filesystem|/$|/var|/home|docker"
echo ""

print_info "Models will be stored in: $OLLAMA_DATA"
print_info "Minimum recommended space: ${MIN_SPACE_GB}GB"
echo ""

# =============================================================================
# Fix Swap File (Prevent filling root partition)
# =============================================================================
print_step "Optimizing swap configuration..."

if [ -f /swap.img ]; then
    SWAP_SIZE_MB=$(du -m /swap.img 2>/dev/null | cut -f1 || echo "0")
    print_info "Found swap.img on root: ${SWAP_SIZE_MB}MB"
    
    if [ "$SWAP_SIZE_MB" -gt 4096 ]; then
        print_info "Moving large swap to Docker partition..."
        
        sudo swapoff /swap.img 2>/dev/null || true
        sudo rm -f /swap.img
        sudo sed -i '/swap.img/d' /etc/fstab
        
        sudo fallocate -l $SWAP_SIZE /var/lib/docker/swapfile 2>/dev/null || sudo dd if=/dev/zero of=/var/lib/docker/swapfile bs=1M count=2048
        sudo chmod 600 /var/lib/docker/swapfile
        sudo mkswap /var/lib/docker/swapfile
        sudo swapon /var/lib/docker/swapfile
        
        if ! grep -q "/var/lib/docker/swapfile" /etc/fstab; then
            echo '/var/lib/docker/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        fi
        
        print_success "Swap moved to Docker partition ($SWAP_SIZE)"
    fi
else
    print_success "No large swap on root partition"
fi

# =============================================================================
# Limit Journal Size
# =============================================================================
print_step "Configuring journal size limit..."

sudo mkdir -p /etc/systemd/journald.conf.d/
sudo tee /etc/systemd/journald.conf.d/size-limit.conf > /dev/null << EOF
[Journal]
SystemMaxUse=$JOURNAL_MAX
SystemMaxFileSize=100M
RuntimeMaxUse=100M
EOF

sudo systemctl restart systemd-journald 2>/dev/null || true
sudo journalctl --vacuum-size=$JOURNAL_MAX 2>/dev/null || true

print_success "Journal limited to $JOURNAL_MAX"

# =============================================================================
# Install Ollama
# =============================================================================
print_step "Installing Ollama..."

if command -v ollama &> /dev/null; then
    print_success "Ollama already installed"
else
    curl -fsSL https://ollama.com/install.sh | sh
    print_success "Ollama installed"
fi

# =============================================================================
# Configure Storage in Large Partition
# =============================================================================
print_step "Configuring Ollama storage in large partition..."

sudo systemctl stop ollama 2>/dev/null || true

sudo mkdir -p "$OLLAMA_DATA/models"
sudo chown -R ollama:ollama "$OLLAMA_DATA"
sudo chmod -R 755 "$OLLAMA_DATA"

if [[ "$OLLAMA_DATA" == /var/lib/docker/* ]]; then
    sudo chmod o+x /var/lib/docker
fi

sudo rm -rf /usr/share/ollama/.ollama 2>/dev/null || true
sudo ln -sf "$OLLAMA_DATA" /usr/share/ollama/.ollama
sudo chown -h ollama:ollama /usr/share/ollama/.ollama

rm -rf ~/.ollama 2>/dev/null || true
ln -sf "$OLLAMA_DATA" ~/.ollama

print_success "Storage configured at $OLLAMA_DATA"

# =============================================================================
# Configure Ollama Service
# =============================================================================
print_step "Configuring Ollama service..."

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

print_success "Service configured"

# =============================================================================
# Create Disk Monitoring & Auto-Cleanup Scripts
# =============================================================================
print_step "Creating disk protection scripts..."

mkdir -p "$INSTALL_DIR"

# Disk monitor script
cat > "$INSTALL_DIR/disk-monitor.sh" << 'SCRIPT'
#!/bin/bash
# Disk monitoring and auto-cleanup script

THRESHOLD=85
OLLAMA_DATA="/var/lib/docker/ollama-data"

get_usage() {
    df "$1" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'
}

ROOT_USAGE=$(get_usage /)
DOCKER_USAGE=$(get_usage /var/lib/docker)

echo "📊 Disk Usage: Root=${ROOT_USAGE}% Docker=${DOCKER_USAGE:-$ROOT_USAGE}%"

CLEANUP_NEEDED=0
[ "$ROOT_USAGE" -gt "$THRESHOLD" ] && CLEANUP_NEEDED=1
[ -n "$DOCKER_USAGE" ] && [ "$DOCKER_USAGE" -gt "$THRESHOLD" ] && CLEANUP_NEEDED=1

if [ "$CLEANUP_NEEDED" -eq 1 ]; then
    echo "🧹 Cleaning up..."
    sudo apt clean 2>/dev/null
    sudo journalctl --vacuum-size=500M 2>/dev/null
    find "$OLLAMA_DATA" -name "*-partial" -type f -delete 2>/dev/null
    docker system prune -f 2>/dev/null
    echo "📊 After cleanup:"
    df -h / /var/lib/docker 2>/dev/null | tail -2
else
    echo "✅ Disk space OK"
fi
SCRIPT
chmod +x "$INSTALL_DIR/disk-monitor.sh"

# Safe pull script
cat > "$INSTALL_DIR/safe-pull.sh" << 'SCRIPT'
#!/bin/bash
# Safe model download - checks space first

MODEL="$1"
MIN_SPACE=15

if [ -z "$MODEL" ]; then
    echo "Usage: ./safe-pull.sh <model-name>"
    echo "Example: ./safe-pull.sh qwen2.5-coder:14b"
    exit 1
fi

echo "📊 Checking disk space..."

AVAIL=$(df /var/lib/docker 2>/dev/null | tail -1 | awk '{gsub(/[^0-9]/,"",$4); print $4}')
[ -z "$AVAIL" ] && AVAIL=$(df / | tail -1 | awk '{gsub(/[^0-9]/,"",$4); print $4}')

# Convert to GB if in KB/MB
[ "$AVAIL" -gt 1000000 ] && AVAIL=$((AVAIL / 1024 / 1024))
[ "$AVAIL" -gt 1000 ] && AVAIL=$((AVAIL / 1024))

if [ "$AVAIL" -lt "$MIN_SPACE" ]; then
    echo "❌ Only ${AVAIL}GB available! Need ${MIN_SPACE}GB minimum."
    echo "Run: ~/local-ai/disk-monitor.sh"
    exit 1
fi

echo "✅ Space OK (${AVAIL}GB free)"
echo "📥 Downloading: $MODEL"
ollama pull "$MODEL"
SCRIPT
chmod +x "$INSTALL_DIR/safe-pull.sh"

print_success "Protection scripts created"

# =============================================================================
# Setup Auto-Monitoring Cron
# =============================================================================
print_step "Setting up automatic monitoring..."

(crontab -l 2>/dev/null | grep -v "disk-monitor.sh"; echo "0 */6 * * * $INSTALL_DIR/disk-monitor.sh >> $INSTALL_DIR/disk-monitor.log 2>&1") | crontab - 2>/dev/null || true

print_success "Auto-monitoring enabled (every 6 hours)"

# =============================================================================
# Start Ollama
# =============================================================================
print_step "Starting Ollama..."

sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama

print_info "Waiting for Ollama to start..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        print_success "Ollama is running!"
        break
    fi
    sleep 2
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 3 Complete - Full Storage Protection Enabled!         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🛡️  Protection Features:"
echo "   ✓ Models stored in: $OLLAMA_DATA"
echo "   ✓ Swap optimized (max ${SWAP_SIZE})"
echo "   ✓ Journal limited to $JOURNAL_MAX"
echo "   ✓ Auto-cleanup every 6 hours"
echo ""
echo "📁 Scripts:"
echo "   ~/local-ai/safe-pull.sh <model>  - Safe download"
echo "   ~/local-ai/disk-monitor.sh       - Check & cleanup"
echo ""
echo "Next: ./04-download-models.sh"
echo ""
