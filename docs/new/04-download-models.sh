#!/bin/bash

# =============================================================================
# 📦 STEP 4: DOWNLOAD AI MODELS (WITH SPACE CHECK)
# =============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
print_success() { echo -e "${GREEN}  ✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}  ⚠${NC} $1"; }
print_error() { echo -e "${RED}  ✗${NC} $1"; }
print_info() { echo -e "${CYAN}  ℹ${NC} $1"; }

OLLAMA_DATA="/var/lib/docker/ollama-data"
MIN_SPACE_GB=30

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  📦 Step 4: Download AI Models (with Space Protection)         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# Check Ollama Running
# =============================================================================
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    print_error "Ollama is not running!"
    echo "Run: sudo systemctl start ollama"
    exit 1
fi

# =============================================================================
# Check Disk Space Function
# =============================================================================
check_space() {
    local required=$1
    local avail_kb=$(df "$OLLAMA_DATA" 2>/dev/null | tail -1 | awk '{print $4}' || df / | tail -1 | awk '{print $4}')
    local avail_gb=$((avail_kb / 1024 / 1024))
    
    echo ""
    print_info "Available space: ${avail_gb}GB"
    print_info "Required for next model: ~${required}GB"
    
    if [ "$avail_gb" -lt "$required" ]; then
        print_error "Not enough space! Need ${required}GB, have ${avail_gb}GB"
        echo ""
        echo "Options:"
        echo "  1. Run cleanup: ~/local-ai/disk-monitor.sh"
        echo "  2. Remove unused models: ollama rm <model-name>"
        echo "  3. Skip this model and continue"
        echo ""
        read -p "Skip this model? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 1
        else
            exit 1
        fi
    fi
    return 0
}

# =============================================================================
# Show Current Space
# =============================================================================
print_step "Checking disk space..."
df -h / /var/lib/docker 2>/dev/null | head -3
echo ""

# Get available space
AVAIL_GB=$(df "$OLLAMA_DATA" 2>/dev/null | tail -1 | awk '{print int($4/1024/1024)}' || df / | tail -1 | awk '{print int($4/1024/1024)}')

if [ "$AVAIL_GB" -lt "$MIN_SPACE_GB" ]; then
    print_error "Only ${AVAIL_GB}GB available! Need at least ${MIN_SPACE_GB}GB for all models."
    echo ""
    echo "Models require approximately:"
    echo "  - qwen2.5-coder:14b  ~9GB"
    echo "  - qwen2.5-coder:7b   ~5GB"
    echo "  - deepseek-r1:14b    ~9GB"
    echo "  - nomic-embed-text   ~0.3GB"
    echo "  ─────────────────────────"
    echo "  Total:               ~24GB"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_warning "This will download approximately 25GB of models"
print_warning "Estimated time: 30-60 minutes depending on internet speed"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# =============================================================================
# Download Models with Space Check
# =============================================================================

# Model 1: Qwen2.5-Coder-14B
print_step "[1/5] Qwen2.5-Coder-14B (~9GB)"
print_info "Best overall coding model for 12GB VRAM"
if check_space 10; then
    ollama pull qwen2.5-coder:14b
    print_success "Qwen2.5-Coder-14B downloaded"
else
    print_warning "Skipped qwen2.5-coder:14b"
fi

# Model 2: Qwen2.5-Coder-7B
print_step "[2/5] Qwen2.5-Coder-7B (~5GB)"
print_info "Faster model for quick tasks & autocomplete"
if check_space 6; then
    ollama pull qwen2.5-coder:7b
    print_success "Qwen2.5-Coder-7B downloaded"
else
    print_warning "Skipped qwen2.5-coder:7b"
fi

# Model 3: DeepSeek-R1
print_step "[3/5] DeepSeek-R1:14B (~9GB)"
print_info "Best for complex reasoning & debugging"
if check_space 10; then
    ollama pull deepseek-r1:14b
    print_success "DeepSeek-R1:14B downloaded"
else
    print_warning "Skipped deepseek-r1:14b"
fi

# Model 4: Embedding model (small)
print_step "[4/5] nomic-embed-text (~274MB)"
print_info "For RAG/document search"
if check_space 1; then
    ollama pull nomic-embed-text
    print_success "nomic-embed-text downloaded"
else
    print_warning "Skipped nomic-embed-text"
fi

# Model 5: Custom coding assistant
print_step "[5/5] Creating custom coding-assistant model"

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
- Respons dalam bahasa yang sama dengan pertanyaan user (Indonesia/English)

Coding Standards:
- Selalu gunakan type hints untuk Python
- Tambahkan docstrings untuk functions
- Handle error dengan proper try/except
- Ikuti best practices dan design patterns"""

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
MODELFILE

if ollama list | grep -q "qwen2.5-coder:14b"; then
    ollama create coding-assistant -f /tmp/Modelfile-coding
    print_success "Custom coding-assistant created"
else
    print_warning "Skipped coding-assistant (base model not available)"
fi
rm -f /tmp/Modelfile-coding

# =============================================================================
# Cleanup Partial Downloads
# =============================================================================
print_step "Cleaning up partial downloads..."
find "$OLLAMA_DATA" -name "*-partial" -type f -delete 2>/dev/null || true
print_success "Cleanup complete"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 4 Complete - Models Downloaded!                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Installed Models:"
ollama list
echo ""
echo "💾 Disk Usage:"
df -h "$OLLAMA_DATA" 2>/dev/null || df -h /
echo ""
echo "🧪 Quick Test:"
echo "   ollama run coding-assistant 'Write hello world in Python'"
echo ""
echo "Next: ./05-setup-webui.sh"
echo ""
