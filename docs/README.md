# 🤖 Panduan Setup AI Coding Assistant Lokal

## Spesifikasi Hardware Target
- **GPU**: RTX 3060 12GB VRAM
- **RAM**: 64GB
- **Storage**: 256GB NVMe + 1TB SATA

---

## 📋 Daftar Isi

1. [Arsitektur Sistem](#arsitektur-sistem)
2. [Instalasi Prerequisites](#instalasi-prerequisites)
3. [Setup Ollama](#setup-ollama)
4. [Setup Open WebUI](#setup-open-webui)
5. [Download & Konfigurasi Model](#download--konfigurasi-model)
6. [Optimasi untuk Coding](#optimasi-untuk-coding)
7. [Strategi Unlimited Context](#strategi-unlimited-context)
8. [Troubleshooting](#troubleshooting)

---

## 🏗️ Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                    Browser (localhost:3000)                     │
├─────────────────────────────────────────────────────────────────┤
│                        Open WebUI                               │
│              (UI mirip Claude/ChatGPT)                          │
├─────────────────────────────────────────────────────────────────┤
│                     Ollama API (:11434)                         │
│              (OpenAI Compatible Endpoint)                       │
├─────────────────────────────────────────────────────────────────┤
│                    Model Layer                                  │
│         Qwen2.5-Coder-14B / DeepSeek-Coder                     │
├─────────────────────────────────────────────────────────────────┤
│                    Hardware                                     │
│              RTX 3060 12GB + 64GB RAM                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Instalasi Prerequisites

### 1. Update Sistem (Ubuntu/Debian)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential
```

### 2. Install NVIDIA Driver & CUDA

```bash
# Cek driver sudah terinstall
nvidia-smi

# Jika belum, install driver
sudo apt install -y nvidia-driver-535

# Install CUDA Toolkit
sudo apt install -y nvidia-cuda-toolkit

# Reboot
sudo reboot
```

### 3. Install Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user ke docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Logout dan login kembali, lalu verifikasi
docker --version
docker compose version
```

### 4. Install NVIDIA Container Toolkit

```bash
# Add repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verifikasi
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

---

## 🦙 Setup Ollama

### Opsi A: Install Native (Rekomendasi untuk performa terbaik)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verifikasi instalasi
ollama --version

# Start Ollama service
sudo systemctl enable ollama
sudo systemctl start ollama

# Cek status
sudo systemctl status ollama
```

### Opsi B: Install via Docker

```bash
docker run -d \
  --name ollama \
  --gpus all \
  -v ollama_data:/root/.ollama \
  -p 11434:11434 \
  --restart unless-stopped \
  ollama/ollama
```

### Konfigurasi Ollama untuk RTX 3060

Buat file konfigurasi environment:

```bash
sudo nano /etc/systemd/system/ollama.service.d/override.conf
```

Isi dengan:

```ini
[Service]
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_GPU_OVERHEAD=512"
Environment="CUDA_VISIBLE_DEVICES=0"
```

Reload dan restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 🖥️ Setup Open WebUI

### Menggunakan Docker Compose (Rekomendasi)

Buat direktori project:

```bash
mkdir -p ~/local-ai && cd ~/local-ai
```

Buat file `docker-compose.yml`:

```yaml
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui-data:/app/backend/data
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - WEBUI_AUTH=false
      - ENABLE_RAG_WEB_SEARCH=true
      - RAG_EMBEDDING_MODEL=nomic-embed-text
      - CHUNK_SIZE=1500
      - CHUNK_OVERLAP=100
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

volumes:
  open-webui-data:
```

Jalankan:

```bash
docker compose up -d
```

Akses di browser: **http://localhost:3000**

---

## 📦 Download & Konfigurasi Model

### Model Rekomendasi untuk RTX 3060 12GB

| Model | Command | VRAM | Use Case |
|-------|---------|------|----------|
| **Qwen2.5-Coder-14B-Q4** | `ollama pull qwen2.5-coder:14b` | ~10GB | ⭐ Best all-round |
| Qwen2.5-Coder-7B-Q8 | `ollama pull qwen2.5-coder:7b` | ~8GB | Cepat & ringan |
| DeepSeek-Coder-V2-Lite | `ollama pull deepseek-coder-v2:16b` | ~11GB | MoE, efisien |
| CodeQwen1.5-7B | `ollama pull codeqwen:7b` | ~8GB | Alternatif solid |

### Download Model Utama

```bash
# Model coding utama (pilih salah satu)
ollama pull qwen2.5-coder:14b

# Model untuk embedding (untuk RAG)
ollama pull nomic-embed-text

# Opsional: Model chat general
ollama pull qwen2.5:7b
```

### Verifikasi Model

```bash
# List semua model
ollama list

# Test model
ollama run qwen2.5-coder:14b "Write a Python function to calculate fibonacci"
```

### Custom Modelfile untuk Coding Optimization

Buat file `Modelfile-coder`:

```dockerfile
FROM qwen2.5-coder:14b

# System prompt untuk coding assistant
SYSTEM """You are an expert coding assistant. You help with:
- Writing clean, efficient code
- Debugging and fixing issues
- Code review and optimization
- Explaining complex concepts
- Best practices and patterns

Always provide complete, working code with explanations.
Use proper formatting with code blocks.
Consider edge cases and error handling."""

# Parameter optimization untuk coding
PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER num_ctx 32768
PARAMETER repeat_penalty 1.1
PARAMETER stop "<|endoftext|>"
PARAMETER stop "<|im_end|>"
```

Buat model custom:

```bash
ollama create coding-assistant -f Modelfile-coder
```

---

## ⚡ Optimasi untuk Coding

### 1. Konfigurasi Open WebUI untuk Coding

Di Open WebUI, buat **Model Preset** baru:

**Settings → Models → Create New**

```yaml
Name: Coding Assistant
Model: qwen2.5-coder:14b (atau coding-assistant jika sudah buat custom)
System Prompt: |
  You are an expert senior software engineer and coding assistant.
  
  Guidelines:
  - Always write clean, readable, well-documented code
  - Follow best practices and design patterns
  - Include error handling and edge cases
  - Provide explanations for complex logic
  - Use appropriate data structures and algorithms
  - Consider performance and scalability
  - Write unit tests when asked
  
  Response format:
  - Use markdown code blocks with language specification
  - Structure responses clearly with headers when needed
  - Be concise but thorough

Temperature: 0.3
Top P: 0.9
Context Length: 32768
```

### 2. Keyboard Shortcuts untuk Produktivitas

Di Open WebUI Settings:

- `Ctrl + K` : New chat
- `Ctrl + Shift + C` : Copy last code block
- `Ctrl + Enter` : Send message

### 3. Enable Code Highlighting

Open WebUI sudah mendukung syntax highlighting untuk 100+ bahasa. Pastikan menggunakan code blocks:

````markdown
```python
def hello():
    print("Hello, World!")
```
````

---

## 🔄 Strategi Unlimited Context

### Pendekatan 1: Long Context Native

Qwen2.5-Coder mendukung hingga **128K tokens** native. Untuk mengaktifkan:

```bash
# Edit Modelfile
PARAMETER num_ctx 65536  # atau 131072 untuk 128K
```

**Catatan**: Context lebih panjang = VRAM lebih banyak. Untuk 12GB:
- 32K context → Aman
- 64K context → Kemungkinan perlu CPU offload
- 128K context → Pasti perlu CPU offload (lambat tapi bisa)

### Pendekatan 2: RAG (Retrieval Augmented Generation)

Setup RAG untuk codebase:

```bash
# Di Open WebUI, aktifkan Documents feature
# Upload codebase Anda sebagai knowledge base
```

**Struktur yang Direkomendasikan:**

```
my-codebase/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── api-reference.md
│   └── setup-guide.md
├── src/
│   └── ... (code files)
└── knowledge/
    └── coding-standards.md
```

### Pendekatan 3: Context Compression

Untuk percakapan panjang, gunakan summarization:

1. Setelah 10-15 turns, minta AI untuk merangkum konteks
2. Start chat baru dengan summary sebagai context
3. Lanjutkan dari situ

### Pendekatan 4: Hybrid CPU-GPU Offloading

Untuk context sangat panjang dengan 64GB RAM:

```bash
# Set environment variable
export OLLAMA_NUM_GPU=999
export OLLAMA_GPU_LAYER_BALANCE=0.8  # 80% GPU, 20% CPU

# Atau di Modelfile
PARAMETER num_gpu 35  # Jumlah layer di GPU
```

---

## 🛠️ Troubleshooting

### Problem: Out of Memory (OOM)

```bash
# Kurangi context length
ollama run qwen2.5-coder:14b --num-ctx 16384

# Atau gunakan model lebih kecil
ollama pull qwen2.5-coder:7b
```

### Problem: Slow Response

```bash
# Cek GPU utilization
nvidia-smi -l 1

# Pastikan model ter-load di GPU
ollama ps
```

### Problem: Ollama Tidak Terdeteksi

```bash
# Cek Ollama running
curl http://localhost:11434/api/tags

# Restart Ollama
sudo systemctl restart ollama
```

### Problem: Open WebUI Tidak Konek

```bash
# Cek Docker network
docker logs open-webui

# Pastikan OLLAMA_BASE_URL benar
# Untuk Linux native Ollama: http://host.docker.internal:11434
# Untuk Ollama Docker: http://ollama:11434
```

---

## 📊 Monitoring & Maintenance

### Script Monitor GPU

Buat file `monitor.sh`:

```bash
#!/bin/bash
watch -n 1 'echo "=== GPU Status ===" && nvidia-smi && echo "" && echo "=== Ollama Status ===" && ollama ps'
```

### Backup Data

```bash
# Backup Open WebUI data
docker cp open-webui:/app/backend/data ./backup/open-webui-data

# Backup Ollama models
cp -r ~/.ollama/models ./backup/ollama-models
```

### Update Komponen

```bash
# Update Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Update Open WebUI
cd ~/local-ai
docker compose pull
docker compose up -d
```

---

## 🎯 Tips untuk Coding Workflow

### 1. Template Prompt untuk Coding

**Code Review:**
```
Review this code for:
- Bugs and potential issues
- Performance optimizations  
- Best practices violations
- Security concerns

[paste code here]
```

**Debugging:**
```
I'm getting this error:
[paste error]

In this code:
[paste code]

Help me fix it.
```

**New Feature:**
```
Create a [feature description] with these requirements:
- [requirement 1]
- [requirement 2]

Tech stack: [your stack]
```

### 2. Project Context

Untuk project besar, buat file `CONTEXT.md`:

```markdown
# Project Context

## Tech Stack
- Backend: Python/FastAPI
- Frontend: React/TypeScript
- Database: PostgreSQL

## Architecture
[describe architecture]

## Coding Standards
- Use type hints
- Follow PEP 8
- Write docstrings
```

Upload file ini ke Open WebUI Documents untuk persistent context.

---

## 📞 Resources

- [Ollama Documentation](https://ollama.com/library)
- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
- [Qwen2.5-Coder Model Card](https://huggingface.co/Qwen/Qwen2.5-Coder-32B-Instruct)
- [DeepSeek-Coder GitHub](https://github.com/deepseek-ai/DeepSeek-Coder)

---

*Created for RTX 3060 12GB + 64GB RAM setup*
*Last updated: January 2026*
