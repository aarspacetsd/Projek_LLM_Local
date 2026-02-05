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

def check_root():
    if os.geteuid() != 0:
        print(f"{RED}This script must be run as root. Please use sudo.{NC}")
        sys.exit(1)

def check_ubuntu():
    try:
        with open('/etc/os-release', 'r') as f:
            for line in f:
                if line.startswith('ID='):
                    if 'ubuntu' not in line.lower():
                        print(f"{RED}This script is intended for Ubuntu. Exiting.{NC}")
                        sys.exit(1)
    except FileNotFoundError:
        print(f"{RED}Could not find /etc/os-release file. Exiting.{NC}")
        sys.exit(1)

def install_prerequisites():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing prerequisites...{NC}")

def install_nvidia_driver():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing NVIDIA driver...{NC}")

def install_docker():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing Docker...{NC}")

def install_nvidia_container_toolkit():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing NVIDIA Container Toolkit...{NC}")

def install_ollama():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing Ollama...{NC}")

def download_models():
    # Placeholder for actual installation logic
    print(f"{GREEN}Downloading AI models...{NC}")

def setup_services():
    # Placeholder for actual installation logic
    print(f"{GREEN}Setting up services...{NC}")

def install_tools_and_helpers():
    # Placeholder for actual installation logic
    print(f"{GREEN}Installing tools and creating helper scripts...{NC}")

def print_summary():
    # Placeholder for actual summary logic
    print(f"{CYAN}Installation complete.{NC}")

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
