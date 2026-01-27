#!/bin/bash

# =============================================================================
# 📦 DOWNLOAD AI MODELS
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
mkdir -p "$INSTALL_DIR"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  📦 Downloading AI Models              ║"
echo "╚════════════════════════════════════════╝"
echo ""
print_warning "Download bisa memakan waktu 15-45 menit"
print_info "Total download: ~15GB"
echo ""

# -----------------------------------------------------------------------------
# Check Ollama
# -----------------------------------------------------------------------------
if ! command -v ollama &> /dev/null; then
    echo "Error: Ollama belum terinstall!"
    echo "Jalankan: ./02-install-ollama.sh"
    exit 1
fi

if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Starting Ollama..."
    sudo systemctl start ollama
    sleep 5
fi

# -----------------------------------------------------------------------------
# Download Models
# -----------------------------------------------------------------------------

# Model 1: Qwen2.5-Coder-14B (Main model)
print_step "[1/4] Downloading Qwen2.5-Coder-14B (~9GB)..."
print_info "Model utama untuk coding - performa terbaik untuk 12GB VRAM"
ollama pull qwen2.5-coder:14b
print_success "Qwen2.5-Coder-14B selesai!"

# Model 2: Qwen2.5-Coder-7B (Fast model)
print_step "[2/4] Downloading Qwen2.5-Coder-7B (~4.7GB)..."
print_info "Model cepat untuk task ringan"
ollama pull qwen2.5-coder:7b
print_success "Qwen2.5-Coder-7B selesai!"

# Model 3: Embedding model for RAG
print_step "[3/4] Downloading nomic-embed-text (~274MB)..."
print_info "Model untuk RAG/document search"
ollama pull nomic-embed-text
print_success "nomic-embed-text selesai!"

# -----------------------------------------------------------------------------
# Create Custom Coding Model
# -----------------------------------------------------------------------------
print_step "[4/4] Creating custom coding-assistant model..."

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
- Respons dalam bahasa yang sama dengan pertanyaan user (Indonesia/English)"""

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
EOF

ollama create coding-assistant -f "$INSTALL_DIR/Modelfile-coding"
print_success "Custom model 'coding-assistant' dibuat!"

# -----------------------------------------------------------------------------
# Show installed models
# -----------------------------------------------------------------------------
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Models Downloaded!                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📦 Installed Models:"
echo "────────────────────────────────────────"
ollama list
echo ""
echo "🧪 Quick Test:"
echo "────────────────────────────────────────"
echo "ollama run coding-assistant \"Write hello world in Python\""
echo ""
echo "Next step: ./04-install-openwebui.sh"
echo ""
