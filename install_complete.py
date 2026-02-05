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
    print("╔══════════════════════════════════════════════════════════════