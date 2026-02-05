#!/bin/bash

# FRP (Fast Reverse Proxy) Setup Script
# This script installs and configures FRP client for exposing local services
# Author: Ahmad Akmal
# Version: 1.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
FRP_VERSION="0.55.1"
FRP_ARCH="amd64"
INSTALL_DIR="/opt/frp"
CONFIG_DIR="/etc/frp"
SERVICE_FILE="/etc/systemd/system/frpc.service"

# Function to print colored messages
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_message $RED "Error: This script must be run as root"
        exit 1
    fi
}

# Function to detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            FRP_ARCH="amd64"
            ;;
        aarch64|arm64)
            FRP_ARCH="arm64"
            ;;
        armv7l)
            FRP_ARCH="arm"
            ;;
        *)
            print_message $RED "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    print_message $GREEN "Detected architecture: $FRP_ARCH"
}

# Function to install dependencies
install_dependencies() {
    print_message $BLUE "Installing dependencies..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y wget tar
    elif command -v yum &> /dev/null; then
        yum install -y wget tar
    else
        print_message $RED "Unsupported package manager"
        exit 1
    fi
}

# Function to download and install FRP
install_frp() {
    print_message $BLUE "Downloading FRP v${FRP_VERSION}..."
    
    local download_url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"
    local temp_file="/tmp/frp.tar.gz"
    
    wget -q --show-progress -O "$temp_file" "$download_url"
    
    if [ $? -ne 0 ]; then
        print_message $RED "Failed to download FRP"
        exit 1
    fi
    
    print_message $BLUE "Extracting FRP..."
    mkdir -p "$INSTALL_DIR"
    tar -xzf "$temp_file" -C /tmp/
    
    local extracted_dir="/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}"
    cp "$extracted_dir/frpc" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/frpc"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Cleanup
    rm -rf "$temp_file" "$extracted_dir"
    
    print_message $GREEN "FRP client installed successfully to $INSTALL_DIR"
}

# Function to create configuration file
create_config() {
    print_message $BLUE "Creating configuration file..."
    
    cat > "$CONFIG_DIR/frpc.toml" << 'CONFIGEOF'
# FRP Client Configuration
# Documentation: https://github.com/fatedier/frp

# Server Configuration
serverAddr = "YOUR_SERVER_IP"
serverPort = 7000

# Authentication
auth.method = "token"
auth.token = "YOUR_TOKEN_HERE"

# Transport Configuration
transport.protocol = "tcp"
# transport.tls.enable = true  # Uncomment to enable TLS

# Log Configuration
log.to = "/var/log/frp/frpc.log"
log.level = "info"
log.maxDays = 3

# Web Server (for admin interface)
webServer.addr = "127.0.0.1"
webServer.port = 7400
webServer.user = "admin"
webServer.password = "admin"

# ============================================
# Service Proxies Configuration
# ============================================

# HTTP Service Example
[[proxies]]
name = "web"
type = "http"
localIP = "127.0.0.1"
localPort = 8080
customDomains = ["your-domain.com"]

# HTTPS Service Example
[[proxies]]
name = "web-https"
type = "https"
localIP = "127.0.0.1"
localPort = 8443
customDomains = ["your-domain.com"]

# SSH Service Example
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000

# Open WebUI Example
[[proxies]]
name = "openwebui"
type = "http"
localIP = "127.0.0.1"
localPort = 3000
customDomains = ["webui.your-domain.com"]

# Ollama API Example
[[proxies]]
name = "ollama"
type = "http"
localIP = "127.0.0.1"
localPort = 11434
customDomains = ["ollama.your-domain.com"]

# VS Code Server Example
[[proxies]]
name = "vscode"
type = "http"
localIP = "127.0.0.1"
localPort = 8443
customDomains = ["vscode.your-domain.com"]

CONFIGEOF

    # Create log directory
    mkdir -p /var/log/frp
    
    print_message $YELLOW "Configuration file created at: $CONFIG_DIR/frpc.toml"
    print_message $YELLOW "Please edit this file with your server details!"
}

# Function to create systemd service
create_service() {
    print_message $BLUE "Creating systemd service..."
    
    cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=FRP Client Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/opt/frp/frpc -c /etc/frp/frpc.toml
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload
    
    print_message $GREEN "Systemd service created successfully"
}

# Function to create helper script
create_helper_script() {
    print_message $BLUE "Creating helper script..."
    
    cat > /usr/local/bin/frpc-manage << 'HELPEREOF'
#!/bin/bash

# FRP Client Management Helper Script

case "$1" in
    start)
        systemctl start frpc
        echo "FRP client started"
        ;;
    stop)
        systemctl stop frpc
        echo "FRP client stopped"
        ;;
    restart)
        systemctl restart frpc
        echo "FRP client restarted"
        ;;
    status)
        systemctl status frpc
        ;;
    enable)
        systemctl enable frpc
        echo "FRP client enabled at boot"
        ;;
    disable)
        systemctl disable frpc
        echo "FRP client disabled at boot"
        ;;
    logs)
        if [ "$2" == "follow" ]; then
            tail -f /var/log/frp/frpc.log
        else
            tail -n 50 /var/log/frp/frpc.log
        fi
        ;;
    config)
        ${EDITOR:-nano} /etc/frp/frpc.toml
        ;;
    reload)
        systemctl reload frpc
        echo "FRP client configuration reloaded"
        ;;
    test)
        /opt/frp/frpc -c /etc/frp/frpc.toml verify
        ;;
    *)
        echo "FRP Client Management"
        echo "Usage: $0 {start|stop|restart|status|enable|disable|logs|config|reload|test}"
        echo ""
        echo "Commands:"
        echo "  start   - Start FRP client"
        echo "  stop    - Stop FRP client"
        echo "  restart - Restart FRP client"
        echo "  status  - Show service status"
        echo "  enable  - Enable auto-start at boot"
        echo "  disable - Disable auto-start at boot"
        echo "  logs    - Show logs (add 'follow' to tail)"
        echo "  config  - Edit configuration file"
        echo "  reload  - Reload configuration"
        echo "  test    - Test configuration file"
        exit 1
        ;;
esac
HELPEREOF

    chmod +x /usr/local/bin/frpc-manage
    
    print_message $GREEN "Helper script created: frpc-manage"
}

# Function to create example server configuration
create_server_example() {
    print_message $BLUE "Creating server configuration example..."
    
    cat > "$CONFIG_DIR/frps.toml.example" << 'SERVEREOF'
# FRP Server Configuration Example
# This file shows how to configure the FRP server
# Place this on your server with public IP

# Bind Configuration
bindAddr = "0.0.0.0"
bindPort = 7000

# Authentication
auth.method = "token"
auth.token = "YOUR_TOKEN_HERE"

# Virtual Host Configuration
vhostHTTPPort = 80
vhostHTTPSPort = 443

# Dashboard
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "admin"

# Log Configuration
log.to = "/var/log/frp/frps.log"
log.level = "info"
log.maxDays = 3

# Transport
transport.maxPoolCount = 5

# Subdomain Configuration (optional)
# subDomainHost = "example.com"

# Install server with:
# wget https://github.com/fatedier/frp/releases/download/v0.55.1/frp_0.55.1_linux_amd64.tar.gz
# tar -xzf frp_0.55.1_linux_amd64.tar.gz
# cp frp_0.55.1_linux_amd64/frps /usr/local/bin/
# mkdir -p /etc/frp
# cp this file to /etc/frp/frps.toml
# Create systemd service similar to client
SERVEREOF

    print_message $GREEN "Server configuration example created"
}

# Function to display post-installation instructions
show_instructions() {
    print_message $GREEN "\n=========================================="
    print_message $GREEN "FRP Client Installation Complete!"
    print_message $GREEN "==========================================\n"
    
    print_message $YELLOW "Next Steps:"
    print_message $NC "1. Edit configuration file:"
    print_message $BLUE "   nano $CONFIG_DIR/frpc.toml"
    print_message $NC ""
    print_message $NC "2. Update these settings:"
    print_message $NC "   - serverAddr: Your FRP server IP"
    print_message $NC "   - auth.token: Your authentication token"
    print_message $NC "   - Configure your services in [[proxies]] sections"
    print_message $NC ""
    print_message $NC "3. Test configuration:"
    print_message $BLUE "   frpc-manage test"
    print_message $NC ""
    print_message $NC "4. Start FRP client:"
    print_message $BLUE "   frpc-manage start"
    print_message $NC ""
    print_message $NC "5. Enable auto-start at boot:"
    print_message $BLUE "   frpc-manage enable"
    print_message $NC ""
    print_message $YELLOW "Management Commands:"
    print_message $BLUE "   frpc-manage {start|stop|restart|status|logs|config}"
    print_message $NC ""
    print_message $YELLOW "Admin Interface:"
    print_message $NC "   http://localhost:7400 (user: admin, pass: admin)"
    print_message $NC ""
    print_message $YELLOW "Server Setup Example:"
    print_message $NC "   See: $CONFIG_DIR/frps.toml.example"
    print_message $NC ""
    print_message $GREEN "==========================================\n"
}

# Main installation flow
main() {
    print_message $BLUE "=========================================="
    print_message $BLUE "FRP Client Setup Script"
    print_message $BLUE "Version: $FRP_VERSION"
    print_message $BLUE "==========================================\n"
    
    check_root
    detect_architecture
    install_dependencies
    install_frp
    create_config
    create_service
    create_helper_script
    create_server_example
    show_instructions
}

# Run main function
main
