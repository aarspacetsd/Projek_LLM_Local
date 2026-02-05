# 📋 Quick Reference Card - Local AI Coding Assistant

## 🚀 Quick Start Commands

```bash
# Start everything
cd ~/local-ai && docker compose up -d

# Stop everything  
cd ~/local-ai && docker compose down

# View logs
docker logs -f open-webui
docker logs -f ollama

# Check GPU usage
nvidia-smi -l 1

# Check loaded models
docker exec ollama ollama ps

# List available models
docker exec ollama ollama list
```

## 🌐 Access URLs

| Service | URL |
|---------|-----|
| **Open WebUI** | http://localhost:3000 |
| Ollama API | http://localhost:11434 |
| API Docs | http://localhost:11434/api |

## 🤖 Model Commands

```bash
# Pull new model
docker exec ollama ollama pull <model-name>

# Run model directly (testing)
docker exec -it ollama ollama run qwen2.5-coder:14b

# Remove model
docker exec ollama ollama rm <model-name>

# Show model info
docker exec ollama ollama show <model-name>
```

## 📊 Recommended Models for 12GB VRAM

| Model | Command | Size | Best For |
|-------|---------|------|----------|
| **Qwen2.5-Coder-14B** | `ollama pull qwen2.5-coder:14b` | ~9GB | All-round coding |
| Qwen2.5-Coder-7B | `ollama pull qwen2.5-coder:7b` | ~5GB | Fast responses |
| DeepSeek-Coder-V2 | `ollama pull deepseek-coder-v2:16b` | ~10GB | Complex tasks |
| CodeLlama-13B | `ollama pull codellama:13b` | ~7GB | Meta's model |

## 💬 Effective Prompting

### Code Generation
```
Create a [language] function that:
- Does [X]
- Handles [edge case]
- Returns [type]

Include error handling and comments.
```

### Debugging
```
I'm getting this error:
[paste error]

Code:
[paste code]

What's wrong and how do I fix it?
```

### Code Review
```
Review this code for:
- Bugs
- Performance issues
- Security concerns
- Best practices

[paste code]
```

### Explain Code
```
Explain this code step by step:
[paste code]

Focus on [specific aspect].
```

## ⚙️ Troubleshooting

### Out of Memory
```bash
# Use smaller context
docker exec -it ollama ollama run qwen2.5-coder:7b

# Or reduce context in Open WebUI settings
# Settings → Models → Context Length → 16384
```

### Slow Response
```bash
# Check if model loaded
docker exec ollama ollama ps

# Check GPU usage
nvidia-smi
```

### Connection Issues
```bash
# Restart services
docker compose restart

# Check service health
docker ps
curl http://localhost:11434/api/tags
```

## 🔧 Environment Variables

```bash
# Add to ~/.bashrc
export OLLAMA_HOST=0.0.0.0
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=1
```

## 📁 Important Paths

| What | Path |
|------|------|
| Project dir | `~/local-ai/` |
| Docker Compose | `~/local-ai/docker-compose.yml` |
| Ollama models | Docker volume: `ollama_data` |
| Open WebUI data | Docker volume: `open-webui-data` |
| Uploads | `~/local-ai/uploads/` |

## 🔄 Update Commands

```bash
# Update Ollama
docker compose pull ollama
docker compose up -d ollama

# Update Open WebUI
docker compose pull open-webui
docker compose up -d open-webui

# Update models
docker exec ollama ollama pull qwen2.5-coder:14b
```
