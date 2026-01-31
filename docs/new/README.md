# 🤖 Local AI Coding Assistant - Complete Installation Package

Sistem AI coding assistant lokal dengan **Ollama + Open WebUI + LobeChat + Multiple Models**.

## 📋 Daftar Isi

- [Requirements](#requirements)
- [Quick Install](#quick-install)
- [Step-by-Step Install](#step-by-step-install)
- [Access URLs](#access-urls)
- [Installed Models](#installed-models)
- [Commands & Aliases](#commands--aliases)
- [VS Code Integration](#vs-code-integration)
- [Troubleshooting](#troubleshooting)

---

## Requirements

### Hardware (Minimum)
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | NVIDIA 8GB VRAM | NVIDIA 12GB+ VRAM |
| RAM | 16GB | 32GB+ |
| Storage | 100GB free | 200GB+ free |
| CPU | 4 cores | 8+ cores |

### Software
- Ubuntu 22.04 / 24.04 LTS
- NVIDIA GPU dengan driver support

---

## Quick Install

**One-liner untuk install semua:**

```bash
chmod +x install-complete.sh
./install-complete.sh
```

Script ini akan menginstall:
- ✅ NVIDIA Driver & Container Toolkit
- ✅ Docker & Docker Compose
- ✅ Ollama (LLM Engine)
- ✅ Open WebUI (Chat Interface)
- ✅ LobeChat (Alternative UI + Artifacts)
- ✅ SearXNG (Web Search)
- ✅ AI Models (~25GB)
- ✅ Aider (Terminal AI)
- ✅ Helper Scripts & Aliases

---

## Step-by-Step Install

Jika ingin install per tahap:

```bash
# Make all scripts executable
chmod +x *.sh

# Step 1: Prerequisites & NVIDIA Driver
./01-prerequisites.sh
# (Reboot jika diminta)

# Step 2: Docker & NVIDIA Container Toolkit
./02-install-docker.sh
# (Logout/login jika perlu)

# Step 3: Ollama Installation
./03-install-ollama.sh

# Step 4: Download AI Models (~25GB, 30-60 menit)
./04-download-models.sh

# Step 5: Setup Web UI (Open WebUI + LobeChat)
./05-setup-webui.sh

# Step 6: Tools & Helper Scripts
./06-setup-tools.sh

# Load aliases
source ~/.bashrc
```

---

## Access URLs

Setelah instalasi selesai:

| Service | URL | Deskripsi |
|---------|-----|-----------|
| **Open WebUI** | http://VM-IP:3000 | Main chat interface (seperti Claude/ChatGPT) |
| **LobeChat** | http://VM-IP:3210 | Alternative UI dengan Artifacts |
| **SearXNG** | http://VM-IP:8888 | Web search engine |
| **Ollama API** | http://VM-IP:11434 | LLM API endpoint |

### LobeChat Setup
1. Buka Settings → Language Model → Ollama
2. Set URL: `http://VM-IP:11434`
3. Access Code: `localai123`
4. Pilih models yang ingin digunakan

---

## Installed Models

| Model | Size | Use Case |
|-------|------|----------|
| **coding-assistant** | - | Custom optimized untuk coding |
| **qwen2.5-coder:14b** | ~9GB | Main coding model |
| **qwen2.5-coder:7b** | ~5GB | Fast/lightweight |
| **deepseek-r1:14b** | ~9GB | Complex reasoning & debugging |
| **nomic-embed-text** | ~274MB | RAG embeddings |

### Download Model Tambahan

```bash
# CodeLlama (Meta)
ollama pull codellama:13b-instruct

# StarCoder2 (600+ languages)
ollama pull starcoder2:15b

# CodeGemma (Google)
ollama pull codegemma:7b
```

---

## Commands & Aliases

Setelah `source ~/.bashrc`:

### Service Management
```bash
ai-start      # Start all services
ai-stop       # Stop all services
ai-status     # Check status
ai-update     # Update all components
ai-logs       # View logs
ai-gpu        # Monitor GPU
```

### Model Management
```bash
ai-models     # List installed models
ai-running    # Show loaded models
ai-pull       # Download new model
```

### Aider (Terminal AI Coding)
```bash
aider-qwen      # Qwen 14B (main coding)
aider-deepseek  # DeepSeek R1 (reasoning)
aider-fast      # Qwen 7B (fast)
```

### Project Tools
```bash
ai-import-github https://github.com/user/repo  # Clone repo
ai-index /path/to/project                       # Index for RAG
```

---

## VS Code Integration

### Install Continue Extension

1. Buka VS Code
2. Install extension: **Continue**
3. Copy `continue-config.json` ke `~/.continue/config.json`
4. Ganti `VM_IP_ADDRESS` dengan IP VM Anda

### Continue Commands
- `Ctrl+L` - Open chat
- `Ctrl+I` - Inline edit
- `@codebase` - Query entire project
- `@folder` - Query specific folder
- `@file` - Query specific file

### Custom Commands (dalam Continue)
- `/review` - Code review
- `/explain` - Explain code
- `/test` - Generate tests
- `/refactor` - Suggest refactoring
- `/document` - Add documentation

---

## File Structure

```
local-ai-complete/
├── install-complete.sh      # All-in-one installer
├── 01-prerequisites.sh      # System prerequisites
├── 02-install-docker.sh     # Docker installation
├── 03-install-ollama.sh     # Ollama setup
├── 04-download-models.sh    # Download AI models
├── 05-setup-webui.sh        # Web UI services
├── 06-setup-tools.sh        # Tools & helpers
├── uninstall.sh             # Remove everything
├── continue-config.json     # VS Code Continue config
└── README.md                # This file
```

---

## Troubleshooting

### Services tidak start
```bash
ai-status
sudo systemctl status ollama
docker ps -a
docker logs open-webui
```

### GPU tidak terdeteksi
```bash
nvidia-smi
sudo systemctl restart ollama
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### Disk space penuh
```bash
df -h
docker system prune -a
sudo journalctl --vacuum-time=3d
```

### Ollama error
```bash
sudo systemctl status ollama
sudo journalctl -u ollama -n 50
```

### Model download gagal
```bash
# Check space
df -h

# Retry download
ollama pull qwen2.5-coder:14b
```

### LobeChat tidak connect ke Ollama
1. Pastikan URL benar: `http://VM-IP:11434`
2. Cek Ollama running: `curl http://localhost:11434/api/tags`
3. Cek firewall

---

## Storage Recommendations

Untuk menghindari disk penuh:

1. **Pisahkan partisi untuk Docker** (minimal 100GB)
2. **Simpan Ollama models di partisi besar**
3. **Monitor disk usage** dengan `ai-status`

### Pindahkan Ollama ke partisi lain
Edit `/etc/systemd/system/ollama.service.d/override.conf`:
```ini
Environment="OLLAMA_MODELS=/path/to/large/partition/ollama/models"
```

---

## Uninstall

```bash
./uninstall.sh
```

---

## Resources

- [Ollama Documentation](https://ollama.com/library)
- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [LobeChat GitHub](https://github.com/lobehub/lobe-chat)
- [Continue.dev Documentation](https://continue.dev/docs)
- [Aider Documentation](https://aider.chat/)

---

## License

MIT License - Feel free to modify and distribute.

---

## Credits

Built with ❤️ for local AI coding assistance.

**Models:**
- Qwen2.5-Coder by Alibaba
- DeepSeek-R1 by DeepSeek
- Nomic Embed by Nomic AI

**Tools:**
- Ollama
- Open WebUI
- LobeChat
- Continue.dev
- Aider
