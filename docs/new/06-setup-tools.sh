#!/bin/bash

# =============================================================================
# 🔧 STEP 6: SETUP TOOLS & HELPER SCRIPTS
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

INSTALL_DIR="$HOME/local-ai"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🔧 Step 6: Setup Tools & Helper Scripts                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

cd "$INSTALL_DIR"

# -----------------------------------------------------------------------------
# Install Aider
# -----------------------------------------------------------------------------
print_step "Installing Aider (Git-integrated AI coding)..."
pip install aider-chat --break-system-packages 2>/dev/null || pip install aider-chat
print_success "Aider installed"

# -----------------------------------------------------------------------------
# Create Helper Scripts
# -----------------------------------------------------------------------------
print_step "Creating helper scripts..."

# --- start.sh ---
cat > start.sh << 'SCRIPT'
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

sleep 5

echo ""
echo "✅ Services Started!"
echo ""
echo "📍 Access URLs:"
IP=$(hostname -I | awk '{print $1}')
echo "   Open WebUI:  http://$IP:3000"
echo "   LobeChat:    http://$IP:3210"
echo "   SearXNG:     http://$IP:8888"
echo "   Ollama API:  http://$IP:11434"
echo ""
SCRIPT
chmod +x start.sh

# --- stop.sh ---
cat > stop.sh << 'SCRIPT'
#!/bin/bash
echo "🛑 Stopping Local AI Services..."
echo ""

cd ~/local-ai
docker compose down
sudo systemctl stop ollama

echo "✅ All services stopped"
SCRIPT
chmod +x stop.sh

# --- status.sh ---
cat > status.sh << 'SCRIPT'
#!/bin/bash
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    📊 LOCAL AI STATUS                             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Ollama
echo "🦙 Ollama:"
if systemctl is-active --quiet ollama; then
    echo "   Status: ✅ Running"
    echo "   URL: http://$IP:11434"
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
    echo "   URL: http://$IP:3000"
else
    echo "   Status: ❌ Stopped"
fi
echo ""

# LobeChat
echo "🎨 LobeChat:"
if curl -s http://localhost:3210 > /dev/null 2>&1; then
    echo "   Status: ✅ Running"
    echo "   URL: http://$IP:3210"
else
    echo "   Status: ❌ Stopped"
fi
echo ""

# GPU
echo "🎮 GPU:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader 2>/dev/null | \
        awk -F', ' '{printf "   %s\n   Utilization: %s | Memory: %s / %s | Temp: %s\n", $1, $2, $3, $4, $5}' || \
        echo "   Error reading GPU info"
else
    echo "   nvidia-smi not found"
fi
echo ""

# Disk
echo "💾 Storage:"
df -h / /var/lib/docker 2>/dev/null | tail -n +2 | while read line; do
    echo "   $line"
done
echo ""

# Docker
echo "🐳 Docker Containers:"
docker ps --format "   {{.Names}}: {{.Status}}" 2>/dev/null || echo "   Docker not running"
echo ""

echo "═══════════════════════════════════════════════════════════════════"
SCRIPT
chmod +x status.sh

# --- update.sh ---
cat > update.sh << 'SCRIPT'
#!/bin/bash
echo "🔄 Updating Local AI Components..."
echo ""

# Update Ollama
echo "📦 Updating Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Update Docker images
echo ""
echo "🐳 Updating Docker images..."
cd ~/local-ai
docker compose pull
docker compose up -d

# Update Aider
echo ""
echo "🔧 Updating Aider..."
pip install --upgrade aider-chat --break-system-packages 2>/dev/null || pip install --upgrade aider-chat

echo ""
echo "✅ Update complete!"
SCRIPT
chmod +x update.sh

# --- gpu-watch.sh ---
cat > gpu-watch.sh << 'SCRIPT'
#!/bin/bash
echo "🎮 GPU Monitor (Press Ctrl+C to exit)"
echo ""
watch -n 1 nvidia-smi
SCRIPT
chmod +x gpu-watch.sh

# --- logs.sh ---
cat > logs.sh << 'SCRIPT'
#!/bin/bash
SERVICE=${1:-open-webui}
echo "📋 Logs for: $SERVICE (Ctrl+C to exit)"
echo ""
docker logs -f $SERVICE
SCRIPT
chmod +x logs.sh

# --- models.sh ---
cat > models.sh << 'SCRIPT'
#!/bin/bash
echo "📦 Ollama Models"
echo ""
echo "Installed models:"
ollama list
echo ""
echo "Currently loaded:"
ollama ps
SCRIPT
chmod +x models.sh

# --- pull-model.sh ---
cat > pull-model.sh << 'SCRIPT'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./pull-model.sh <model-name>"
    echo ""
    echo "Popular models:"
    echo "  ollama pull codellama:13b-instruct"
    echo "  ollama pull starcoder2:15b"
    echo "  ollama pull codegemma:7b"
    echo "  ollama pull mistral:7b"
    exit 1
fi
echo "📥 Pulling model: $1"
ollama pull $1
SCRIPT
chmod +x pull-model.sh

print_success "Helper scripts created"

# -----------------------------------------------------------------------------
# Create GitHub/Project Import Script
# -----------------------------------------------------------------------------
print_step "Creating project import tools..."

cat > import-github.sh << 'SCRIPT'
#!/bin/bash
# Import GitHub repository for AI analysis

REPO_URL="$1"

if [ -z "$REPO_URL" ]; then
    echo "Usage: ./import-github.sh https://github.com/owner/repo"
    exit 1
fi

REPO_NAME=$(basename "$REPO_URL" .git)
WORK_DIR=~/github-imports/$REPO_NAME

echo "📥 Importing: $REPO_URL"
mkdir -p ~/github-imports
rm -rf "$WORK_DIR"

git clone --depth 1 "$REPO_URL" "$WORK_DIR"

echo ""
echo "✅ Repository cloned to: $WORK_DIR"
echo ""
echo "Next steps:"
echo "  1. VS Code + Continue: Open folder in VS Code, use @codebase"
echo "  2. Aider: cd $WORK_DIR && aider-qwen"
echo "  3. Index for RAG: python3 ~/local-ai/index-project.py $WORK_DIR"
SCRIPT
chmod +x import-github.sh

# --- index-project.py ---
cat > index-project.py << 'PYTHON'
#!/usr/bin/env python3
"""
Index project files for RAG upload to Open WebUI
Usage: python3 index-project.py /path/to/project [output_dir]
"""

import os
import sys
from pathlib import Path
from datetime import datetime

IGNORED_DIRS = {
    'node_modules', '.git', '__pycache__', 'venv', 'env',
    '.venv', 'dist', 'build', '.next', 'coverage', 'target'
}

CODE_EXTENSIONS = {
    '.py', '.js', '.ts', '.jsx', '.tsx', '.go', '.rs', '.java',
    '.cpp', '.c', '.h', '.cs', '.rb', '.php', '.swift', '.kt',
    '.vue', '.svelte', '.sql', '.sh', '.bash'
}

CONFIG_EXTENSIONS = {
    '.json', '.yaml', '.yml', '.toml', '.ini', '.xml', '.conf',
    '.env.example', '.gitignore', '.dockerignore'
}

def should_ignore(path):
    return any(part in IGNORED_DIRS for part in path.parts)

def get_language(ext):
    lang_map = {
        '.py': 'python', '.js': 'javascript', '.ts': 'typescript',
        '.jsx': 'jsx', '.tsx': 'tsx', '.go': 'go', '.rs': 'rust',
        '.java': 'java', '.cpp': 'cpp', '.c': 'c', '.cs': 'csharp',
        '.rb': 'ruby', '.php': 'php', '.swift': 'swift', '.kt': 'kotlin',
        '.vue': 'vue', '.sql': 'sql', '.sh': 'bash', '.yaml': 'yaml',
        '.yml': 'yaml', '.json': 'json', '.toml': 'toml', '.xml': 'xml'
    }
    return lang_map.get(ext, ext[1:] if ext else 'text')

def index_project(project_path, output_dir='./indexed'):
    project_root = Path(project_path).resolve()
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    print(f"📁 Indexing: {project_root}")
    
    files = []
    for filepath in project_root.rglob('*'):
        if filepath.is_file() and not should_ignore(filepath):
            ext = filepath.suffix.lower()
            if ext in CODE_EXTENSIONS or ext in CONFIG_EXTENSIONS:
                try:
                    content = filepath.read_text(encoding='utf-8', errors='ignore')
                    files.append({
                        'path': str(filepath.relative_to(project_root)),
                        'ext': ext,
                        'content': content[:30000],
                        'lines': content.count('\n') + 1
                    })
                    print(f"  ✓ {filepath.relative_to(project_root)}")
                except:
                    pass
    
    # Write output
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = output_path / f'{project_root.name}_{timestamp}.md'
    
    with open(output_file, 'w') as f:
        f.write(f"# Project: {project_root.name}\n\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n")
        f.write(f"Total files: {len(files)}\n\n")
        f.write("## File Tree\n\n```\n")
        for file in files:
            f.write(f"{file['path']}\n")
        f.write("```\n\n")
        f.write("## Source Code\n\n")
        for file in files:
            f.write(f"### {file['path']}\n\n")
            f.write(f"```{get_language(file['ext'])}\n")
            f.write(file['content'])
            f.write("\n```\n\n")
    
    print(f"\n✅ Indexed {len(files)} files")
    print(f"📄 Output: {output_file}")
    print(f"\nUpload this file to Open WebUI → Documents for RAG!")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 index-project.py /path/to/project [output_dir]")
        sys.exit(1)
    
    project = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 else './indexed'
    index_project(project, output)
PYTHON
chmod +x index-project.py

print_success "Project import tools created"

# -----------------------------------------------------------------------------
# Add Aliases to Bashrc
# -----------------------------------------------------------------------------
print_step "Adding aliases to .bashrc..."

# Check if aliases already exist
if ! grep -q "Local AI Aliases" ~/.bashrc; then
    cat >> ~/.bashrc << 'ALIASES'

# =============================================================================
# Local AI Aliases
# =============================================================================
export LOCAL_AI_DIR="$HOME/local-ai"

# Service management
alias ai-start='$LOCAL_AI_DIR/start.sh'
alias ai-stop='$LOCAL_AI_DIR/stop.sh'
alias ai-status='$LOCAL_AI_DIR/status.sh'
alias ai-update='$LOCAL_AI_DIR/update.sh'
alias ai-logs='$LOCAL_AI_DIR/logs.sh'
alias ai-gpu='$LOCAL_AI_DIR/gpu-watch.sh'

# Model management
alias ai-models='ollama list'
alias ai-running='ollama ps'
alias ai-pull='$LOCAL_AI_DIR/pull-model.sh'

# Aider (Terminal AI coding)
alias aider-qwen='aider --model ollama/qwen2.5-coder:14b'
alias aider-deepseek='aider --model ollama/deepseek-r1:14b'
alias aider-fast='aider --model ollama/qwen2.5-coder:7b'

# Project tools
alias ai-import-github='$LOCAL_AI_DIR/import-github.sh'
alias ai-index='python3 $LOCAL_AI_DIR/index-project.py'
ALIASES
    print_success "Aliases added to .bashrc"
else
    print_info "Aliases already exist in .bashrc"
fi

# -----------------------------------------------------------------------------
# Create README
# -----------------------------------------------------------------------------
print_step "Creating README..."

cat > README.md << 'README'
# 🤖 Local AI Coding Assistant

## Quick Start

```bash
# Start all services
ai-start

# Check status
ai-status

# Stop all services
ai-stop
```

## Access URLs

| Service | URL | Description |
|---------|-----|-------------|
| Open WebUI | http://localhost:3000 | Main chat interface |
| LobeChat | http://localhost:3210 | Alternative UI + Artifacts |
| SearXNG | http://localhost:8888 | Web search |
| Ollama API | http://localhost:11434 | LLM API |

## Commands

### Service Management
- `ai-start` - Start all services
- `ai-stop` - Stop all services
- `ai-status` - Check status
- `ai-update` - Update all components
- `ai-logs [service]` - View logs
- `ai-gpu` - Monitor GPU

### Model Management
- `ai-models` - List installed models
- `ai-running` - Show loaded models
- `ai-pull <model>` - Download new model

### Aider (Terminal AI)
- `aider-qwen` - Qwen 14B (main coding)
- `aider-deepseek` - DeepSeek R1 (reasoning)
- `aider-fast` - Qwen 7B (fast)

### Project Tools
- `ai-import-github <url>` - Clone GitHub repo
- `ai-index /path/to/project` - Index for RAG

## Installed Models

| Model | Use Case | Command |
|-------|----------|---------|
| coding-assistant | Daily coding | Default |
| qwen2.5-coder:14b | Coding (main) | `ollama run qwen2.5-coder:14b` |
| qwen2.5-coder:7b | Quick tasks | `ollama run qwen2.5-coder:7b` |
| deepseek-r1:14b | Reasoning/debug | `ollama run deepseek-r1:14b` |
| nomic-embed-text | RAG embeddings | Auto-used |

## VS Code Integration

Install **Continue** extension and configure:

```json
{
  "models": [
    {
      "title": "Qwen Coder",
      "provider": "ollama",
      "model": "qwen2.5-coder:14b",
      "apiBase": "http://<VM-IP>:11434"
    }
  ]
}
```

## Troubleshooting

### Services not starting
```bash
ai-status
sudo systemctl status ollama
docker ps -a
```

### GPU not detected
```bash
nvidia-smi
sudo systemctl restart ollama
```

### Disk space issues
```bash
df -h
docker system prune -a
```
README

print_success "README.md created"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ Step 6 Complete - All Tools Installed!                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔧 Helper Scripts: $INSTALL_DIR/"
echo ""
echo "📋 Quick Commands (run 'source ~/.bashrc' first):"
echo "   ai-start     - Start services"
echo "   ai-status    - Check status"
echo "   ai-stop      - Stop services"
echo "   aider-qwen   - Terminal AI coding"
echo ""
echo "🎉 Installation Complete!"
echo ""
