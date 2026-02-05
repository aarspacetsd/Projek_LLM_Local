#!/bin/bash

# FRP Server Setup Script for VPS Tunneling
# This script installs and configures FRP server on VPS with public IP
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
SERVICE_FILE="/etc/systemd/system/frps.service"

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

# Function to get public IP
get_public_ip() {
    local ip=$(curl -s ifconfig.me)
    if [ -z "$ip" ]; then
        ip=$(curl -s api.ipify.org)
    fi
    echo "$ip"
}

# Function to generate random token
generate_token() {
    openssl rand -hex 16
}

# Function to install dependencies
install_dependencies() {
    print_message $BLUE "Installing dependencies..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y wget tar curl openssl
    elif command -v yum &> /dev/null; then
        yum install -y wget tar curl openssl
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
    cp "$extracted_dir/frps" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/frps"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Cleanup
    rm -rf "$temp_file" "$extracted_dir"
    
    print_message $GREEN "FRP server installed successfully to $INSTALL_DIR"
}

# Function to configure firewall
configure_firewall() {
    print_message $BLUE "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        print_message $YELLOW "Detected UFW firewall"
        ufw allow 7000/tcp comment 'FRP Server'
        ufw allow 7500/tcp comment 'FRP Dashboard'
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        ufw allow 6000:6100/tcp comment 'FRP TCP Range'
        print_message $GREEN "UFW rules added"
    elif command -v firewall-cmd &> /dev/null; then
        print_message $YELLOW "Detected firewalld"
        firewall-cmd --permanent --add-port=7000/tcp
        firewall-cmd --permanent --add-port=7500/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=6000-6100/tcp
        firewall-cmd --reload
        print_message $GREEN "Firewalld rules added"
    else
        print_message $YELLOW "No firewall detected. Please configure manually:"
        print_message $NC "  - Port 7000 (FRP control)"
        print_message $NC "  - Port 7500 (Dashboard)"
        print_message $NC "  - Port 80 (HTTP)"
        print_message $NC "  - Port 443 (HTTPS)"
        print_message $NC "  - Ports 6000-6100 (TCP proxies)"
    fi
}

# Function to create configuration file
create_config() {
    print_message $BLUE "Creating configuration file..."
    
    local public_ip=$(get_public_ip)
    local token=$(generate_token)
    local dashboard_user="admin"
    local dashboard_pass=$(openssl rand -base64 12)
    
    cat > "$CONFIG_DIR/frps.toml" << CONFIGEOF
# FRP Server Configuration
# Documentation: https://github.com/fatedier/frp

# Bind Configuration
bindAddr = "0.0.0.0"
bindPort = 7000

# Authentication
auth.method = "token"
auth.token = "${token}"

# Virtual Host HTTP/HTTPS Ports
vhostHTTPPort = 80
vhostHTTPSPort = 443

# Dashboard Configuration
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "${dashboard_user}"
webServer.password = "${dashboard_pass}"

# Log Configuration
log.to = "/var/log/frp/frps.log"
log.level = "info"
log.maxDays = 7

# Transport Configuration
transport.maxPoolCount = 5
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 60
transport.tcpKeepalive = 7200

# Connection Limits
maxPortsPerClient = 10

# Allow custom domains and ports
allowPorts = [
    { start = 6000, end = 6100 }
]

# Subdomain Configuration (optional)
# Uncomment and set your domain if you want subdomain support
# subDomainHost = "example.com"

CONFIGEOF

    # Create log directory
    mkdir -p /var/log/frp
    
    # Save credentials to a file
    cat > "$CONFIG_DIR/credentials.txt" << CREDEOF
FRP Server Credentials
======================

Server IP: ${public_ip}
Server Port: 7000
Auth Token: ${token}

Dashboard URL: http://${public_ip}:7500
Dashboard User: ${dashboard_user}
Dashboard Password: ${dashboard_pass}

IMPORTANT: 
- Save this file securely
- Share the token with your FRP clients
- Change dashboard password after first login

Client Configuration Example:
-----------------------------
serverAddr = "${public_ip}"
serverPort = 7000
auth.method = "token"
auth.token = "${token}"

CREDEOF

    chmod 600 "$CONFIG_DIR/credentials.txt"
    
    print_message $GREEN "Configuration file created at: $CONFIG_DIR/frps.toml"
    print_message $GREEN "Credentials saved to: $CONFIG_DIR/credentials.txt"
}

# Function to create systemd service
create_service() {
    print_message $BLUE "Creating systemd service..."
    
    cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=FRP Server Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=always
RestartSec=5s
ExecStart=/opt/frp/frps -c /etc/frp/frps.toml
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
    
    cat > /usr/local/bin/frps-manage << 'HELPEREOF'
#!/bin/bash

# FRP Server Management Helper Script

case "$1" in
    start)
        systemctl start frps
        echo "FRP server started"
        ;;
    stop)
        systemctl stop frps
        echo "FRP server stopped"
        ;;
    restart)
        systemctl restart frps
        echo "FRP server restarted"
        ;;
    status)
        systemctl status frps
        ;;
    enable)
        systemctl enable frps
        echo "FRP server enabled at boot"
        ;;
    disable)
        systemctl disable frps
        echo "FRP server disabled at boot"
        ;;
    logs)
        if [ "$2" == "follow" ]; then
            tail -f /var/log/frp/frps.log
        else
            tail -n 100 /var/log/frp/frps.log
        fi
        ;;
    config)
        ${EDITOR:-nano} /etc/frp/frps.toml
        ;;
    reload)
        systemctl reload frps
        echo "FRP server configuration reloaded"
        ;;
    credentials)
        if [ -f /etc/frp/credentials.txt ]; then
            cat /etc/frp/credentials.txt
        else
            echo "Credentials file not found"
        fi
        ;;
    clients)
        echo "Connected clients:"
        echo "Check dashboard at: http://$(curl -s ifconfig.me):7500"
        ;;
    firewall)
        echo "Firewall status for FRP ports:"
        if command -v ufw &> /dev/null; then
            ufw status | grep -E '7000|7500|80|443|6000'
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --list-ports | grep -E '7000|7500|80|443|6000'
        else
            echo "No firewall detected"
        fi
        ;;
    *)
        echo "FRP Server Management"
        echo "Usage: $0 {start|stop|restart|status|enable|disable|logs|config|reload|credentials|clients|firewall}"
        echo ""
        echo "Commands:"
        echo "  start       - Start FRP server"
        echo "  stop        - Stop FRP server"
        echo "  restart     - Restart FRP server"
        echo "  status      - Show service status"
        echo "  enable      - Enable auto-start at boot"
        echo "  disable     - Disable auto-start at boot"
        echo "  logs        - Show logs (add 'follow' to tail)"
        echo "  config      - Edit configuration file"
        echo "  reload      - Reload configuration"
        echo "  credentials - Show server credentials"
        echo "  clients     - Show connected clients info"
        echo "  firewall    - Check firewall status"
        exit 1
        ;;
esac
HELPEREOF

    chmod +x /usr/local/bin/frps-manage
    
    print_message $GREEN "Helper script created: frps-manage"
}

# Function to create client config template
create_client_template() {
    print_message $BLUE "Creating client configuration template..."
    
    local public_ip=$(get_public_ip)
    local token=$(grep 'auth.token' "$CONFIG_DIR/frps.toml" | cut -d'"' -f2)
    
    cat > "$CONFIG_DIR/client-template.toml" << CLIENTEOF
# FRP Client Configuration Template
# Copy this to your local server and customize

# Server Configuration
serverAddr = "${public_ip}"
serverPort = 7000

# Authentication
auth.method = "token"
auth.token = "${token}"

# Transport Configuration
transport.protocol = "tcp"

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

# SSH Access
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6022

# Open WebUI
[[proxies]]
name = "openwebui"
type = "http"
localIP = "127.0.0.1"
localPort = 3000
# Option 1: Using subdomain (requires subDomainHost on server)
# subdomain = "webui"
# Option 2: Using custom domain
customDomains = ["webui.your-domain.com"]

# Ollama API
[[proxies]]
name = "ollama"
type = "http"
localIP = "127.0.0.1"
localPort = 11434
customDomains = ["ollama.your-domain.com"]

# VS Code Server
[[proxies]]
name = "vscode"
type = "http"
localIP = "127.0.0.1"
localPort = 8443
customDomains = ["vscode.your-domain.com"]

CLIENTEOF

    print_message $GREEN "Client template created at: $CONFIG_DIR/client-template.toml"
}

# Function to display post-installation instructions
show_instructions() {
    local public_ip=$(get_public_ip)
    
    print_message $GREEN "\n=========================================="
    print_message $GREEN "FRP Server Installation Complete!"
    print_message $GREEN "==========================================\n"
    
    print_message $YELLOW "Server Information:"
    print_message $BLUE "  Public IP: ${public_ip}"
    print_message $BLUE "  Server Port: 7000"
    print_message $BLUE "  Dashboard: http://${public_ip}:7500"
    print_message $NC ""
    
    print_message $YELLOW "IMPORTANT - Save Your Credentials:"
    print_message $BLUE "  frps-manage credentials"
    print_message $NC "  Or view: cat /etc/frp/credentials.txt"
    print_message $NC ""
    
    print_message $YELLOW "Next Steps:"
    print_message $NC "1. Start FRP server:"
    print_message $BLUE "   frps-manage start"
    print_message $NC ""
    print_message $NC "2. Enable auto-start at boot:"
    print_message $BLUE "   frps-manage enable"
    print_message $NC ""
    print_message $NC "3. Check server status:"
    print_message $BLUE "   frps-manage status"
    print_message $NC ""
    print_message $NC "4. View credentials for clients:"
    print_message $BLUE "   frps-manage credentials"
    print_message $NC ""
    print_message $NC "5. Configure your local server:"
    print_message $NC "   - Download setup-frp-client.sh to local server"
    print_message $NC "   - Run installation"
    print_message $NC "   - Use token from credentials.txt"
    print_message $NC ""
    
    print_message $YELLOW "Management Commands:"
    print_message $BLUE "   frps-manage {start|stop|restart|status|logs|credentials}"
    print_message $NC ""
    
    print_message $YELLOW "Security Notes:"
    print_message $RED "   ⚠ Change dashboard password after first login"
    print_message $RED "   ⚠ Keep auth token secret"
    print_message $RED "   ⚠ Consider enabling TLS for production"
    print_message $RED "   ⚠ Configure domain DNS to point to: ${public_ip}"
    print_message $NC ""
    
    print_message $YELLOW "Client Template:"
    print_message $NC "   See: $CONFIG_DIR/client-template.toml"
    print_message $NC ""
    
    print_message $GREEN "==========================================\n"
}

# Main installation flow
main() {
    print_message $BLUE "=========================================="
    print_message $BLUE "FRP Server Setup Script"
    print_message $BLUE "VPS Tunneling Configuration"
    print_message $BLUE "Version: $FRP_VERSION"
    print_message $BLUE "==========================================\n"
    
    check_root
    detect_architecture
    install_dependencies
    install_frp
    configure_firewall
    create_config
    create_service
    create_helper_script
    create_client_template
    show_instructions
}

# Run main function
main
