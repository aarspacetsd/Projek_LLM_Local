# 🤖 Local AI Coding Assistant - Installation Scripts

Scripts otomatis untuk menginstall AI Coding Assistant lokal dengan **Ollama + Open WebUI + Qwen2.5-Coder**.

## 📋 Daftar Scripts

| Script | Fungsi |
|--------|--------|
| `install.sh` | **Install semua** sekaligus (recommended) |
| `01-install-prerequisites.sh` | Install Docker & NVIDIA toolkit |
| `02-install-ollama.sh` | Install Ollama |
| `03-download-models.sh` | Download AI models |
| `04-install-openwebui.sh` | Install Open WebUI |
| `uninstall.sh` | Hapus semua komponen |

---

## 🚀 Quick Install (Semua Sekaligus)

```bash
# Download scripts
git clone https://github.com/yourusername/local-ai-scripts.git
cd local-ai-scripts

# Jalankan installer
chmod +x install.sh
./install.sh
```

---

## 📦 Step-by-Step Install

Jika ingin install per tahap:

```bash
# Make all scripts executable
chmod +x *.sh

# Step 1: Prerequisites (Docker, NVIDIA)
./01-install-prerequisites.sh

# Reboot jika diminta, lalu lanjut...

# Step 2: Ollama
./02-install-ollama.sh

# Step 3: Download Models (15-45 menit)
./03-download-models.sh

# Step 4: Open WebUI
./04-install-openwebui.sh
```

---

## 🎯 Setelah Instalasi

### Access URLs
- **Open WebUI**: http://localhost:3000
- **Ollama API**: http://localhost:11434

### Helper Scripts (di ~/local-ai/)
```bash
cd ~/local-ai

./start.sh   # Start semua services
./stop.sh    # Stop semua services
./status.sh  # Cek status
./logs.sh    # Lihat logs
./update.sh  # Update komponen
```

---

## 💻 System Requirements

| Komponen | Minimum | Recommended |
|----------|---------|-------------|
| GPU | NVIDIA 8GB VRAM | NVIDIA 12GB+ VRAM |
| RAM | 16GB | 32GB+ |
| Storage | 50GB | 100GB+ |
| OS | Ubuntu 22.04 | Ubuntu 24.04 |

---

## 📦 Models yang Diinstall

| Model | Size | Fungsi |
|-------|------|--------|
| qwen2.5-coder:14b | ~9GB | Main coding model |
| qwen2.5-coder:7b | ~5GB | Fast/light model |
| nomic-embed-text | ~274MB | RAG embeddings |
| coding-assistant | - | Custom optimized |

---

## 🔧 Troubleshooting

### GPU tidak terdeteksi
```bash
# Cek driver
nvidia-smi

# Jika tidak ada, install driver
sudo ubuntu-drivers autoinstall
sudo reboot
```

### Docker permission denied
```bash
# Add user ke docker group
sudo usermod -aG docker $USER

# Logout dan login kembali
```

### Open WebUI tidak bisa connect ke Ollama
```bash
# Pastikan Ollama running
sudo systemctl status ollama

# Restart jika perlu
sudo systemctl restart ollama
```

### Out of Memory
```bash
# Gunakan model lebih kecil
ollama run qwen2.5-coder:7b
```

---

## 🗑️ Uninstall

```bash
./uninstall.sh
```

---

## 📞 Support

Jika ada masalah, cek:
1. `./status.sh` untuk status services
2. `./logs.sh` untuk logs
3. `nvidia-smi` untuk GPU status
