#!/usr/bin/env python3

import os
import subprocess
import sys
import time
import json

# =============================================================================
# 🤖 LOCAL AI CODING ASSISTANT - COMPLETE INSTALLER
# =============================================================================
# Target: Ubuntu 24.04 dengan NVIDIA GPU (RTX 3060 12GB)
# Components: Ollama, Open WebUI, LobeChat, Models, Tools
# =============================================================================

# -----------------------------------------------------------------------------
# Colors & Variables
# -----------------------------------------------------------------------------
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
NC = '\033[0m'

INSTALL_DIR = os.path.expanduser("~/local-ai")
OLLAMA_DATA = "/var/lib/docker/ollama-data"
LOG_FILE = os.path.join(INSTALL_DIR, "install.log")

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
def print_banner():
    clear()
    print(f"{CYAN}")
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║              🤖 LOCAL AI CODING ASSISTANT                   ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print(f"{NC}")

def clear():
    os.system('cls' if os.name == 'nt' else 'clear')

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    print_banner()
    
    print(f"{YELLOW}This script will install:{NC}")
    print("  • NVIDIA Driver & Container Toolkit")
    print("  • Docker & Docker Compose")
    print("  • Ollama (LLM Engine)")
    print("  • Open WebUI + LobeChat (Web Interfaces)")
    print("  • AI Models (~25GB download)")
    print("  • Aider (Terminal AI tool)")
    print("")
    
    response = input("Continue with installation? (y/n) ")
    if response.lower() != 'y':
        print("Installation cancelled.")
        sys.exit(0)
    
    # Create install directory
    os.makedirs(INSTALL_DIR, exist_ok=True)
    
    # Run installation steps
    check_root()
    check_ubuntu()
    install_prerequisites()
    install_nvidia_driver()
    install_docker()
    install_nvidia_container_toolkit()
    install_ollama()
    download_models()
    setup_services()
    install_tools_and_helpers()
    
    print_summary()
    
    # Reload bashrc
    print("")
    print("Run this to load aliases:")
    print("  source ~/.bashrc")
    print("")
