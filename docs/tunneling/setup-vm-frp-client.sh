#!/bin/bash

# FRP Client Quick Setup for New Proxmox VM
# Run this on each new VM to quickly setup FRP client
# Author: Ahmad Akmal
# Version: 1.0

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Get VM info
get_vm_info() {
    print_message $BLUE "VM Quick Setup"
    echo ""
    
    read -p "VM Name/Identifier (e.g., ai-assistant, dev-server): " VM_NAME
    read -p "VPS IP Address: " VPS_IP
    read -p "FRP Auth Token: " FRP_TOKEN
    
    print_message $YELLOW "Which services to expose? (y/n for each)"
    
    read -p "SSH (port 22)? [y/N]: " ENABLE_SSH
    read -p "HTTP Service (specify port, or skip): " HTTP_PORT
    read -p "Custom domain (or skip): " CUSTOM_DOMAIN
}

# Install FRP Client
install_frp_client() {
    print_message $BLUE "Installing FRP Client..."
    
    # Download and run main setup
    wget -O /tmp/setup-frp.sh https://your-server.com/setup-frp.sh 2>/dev/null || {
        # Fallback: use local copy
        if [ -f "./setup-frp.sh" ]; then
            cp ./setup-frp.sh /tmp/setup-frp.sh
        else
            print_message $RED "Error: setup-frp.sh not found"
            exit 1
        fi
    }
    
    chmod +x /tmp/setup-frp.sh
    bash /tmp/setup-frp.sh
}

# Configure client
configure_client() {
    print_message $BLUE "Configuring FRP Client..."
    
    # Generate unique remote port for SSH
    REMOTE_SSH_PORT=$((6000 + RANDOM % 100))
    
    # Create config
    cat > /etc/frp/frpc.toml << CONFIGEOF
# FRP Client Configuration for ${VM_NAME}
# Generated: $(date)

# Server Configuration
serverAddr = "${VPS_IP}"
serverPort = 7000

# Authentication
auth.method = "token"
auth.token = "${FRP_TOKEN}"

# Transport Configuration
transport.protocol = "tcp"

# Log Configuration
log.to = "/var/log/frp/frpc.log"
log.level = "info"
log.maxDays = 3

# Admin Interface
webServer.addr = "127.0.0.1"
webServer.port = 7400
webServer.user = "admin"
webServer.password = "admin"

# ============================================
# Service Proxies
# ============================================

CONFIGEOF

    # Add SSH if enabled
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        cat >> /etc/frp/frpc.toml << SSHEOF
# SSH Access
[[proxies]]
name = "${VM_NAME}-ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${REMOTE_SSH_PORT}

SSHEOF
        print_message $YELLOW "SSH will be accessible at: ${VPS_IP}:${REMOTE_SSH_PORT}"
    fi
    
    # Add HTTP service if specified
    if [ ! -z "$HTTP_PORT" ]; then
        if [ ! -z "$CUSTOM_DOMAIN" ]; then
            cat >> /etc/frp/frpc.toml << HTTPEOF
# HTTP Service
[[proxies]]
name = "${VM_NAME}-web"
type = "http"
localIP = "127.0.0.1"
localPort = ${HTTP_PORT}
customDomains = ["${CUSTOM_DOMAIN}"]

HTTPEOF
            print_message $YELLOW "HTTP accessible at: http://${CUSTOM_DOMAIN}"
        else
            cat >> /etc/frp/frpc.toml << HTTPEOF
# HTTP Service
[[proxies]]
name = "${VM_NAME}-web"
type = "http"
localIP = "127.0.0.1"
localPort = ${HTTP_PORT}
subdomain = "${VM_NAME}"

HTTPEOF
            print_message $YELLOW "HTTP accessible at: http://${VM_NAME}.yourdomain.com"
        fi
    fi
    
    print_message $GREEN "Configuration created at: /etc/frp/frpc.toml"
}

# Create info file
create_info_file() {
    cat > /root/frp-info.txt << INFOEOF
FRP Client Information for ${VM_NAME}
=====================================
Generated: $(date)

VPS Server: ${VPS_IP}:7000
VM Dashboard: http://localhost:7400

Services:
$([ "$ENABLE_SSH" = "y" ] && echo "- SSH: ${VPS_IP}:${REMOTE_SSH_PORT}")
$([ ! -z "$HTTP_PORT" ] && [ ! -z "$CUSTOM_DOMAIN" ] && echo "- HTTP: http://${CUSTOM_DOMAIN}")
$([ ! -z "$HTTP_PORT" ] && [ -z "$CUSTOM_DOMAIN" ] && echo "- HTTP: http://${VM_NAME}.yourdomain.com")

Management Commands:
- Start:   sudo frpc-manage start
- Stop:    sudo frpc-manage stop
- Restart: sudo frpc-manage restart
- Status:  sudo frpc-manage status
- Logs:    sudo frpc-manage logs
- Config:  sudo frpc-manage config

Auto-start: $(systemctl is-enabled frpc 2>/dev/null || echo "disabled")

INFOEOF

    print_message $GREEN "Info saved to: /root/frp-info.txt"
}

# Start service
start_service() {
    print_message $BLUE "Starting FRP Client..."
    
    systemctl start frpc
    systemctl enable frpc
    
    sleep 2
    
    if systemctl is-active --quiet frpc; then
        print_message $GREEN "✓ FRP Client is running"
    else
        print_message $RED "✗ Failed to start FRP Client"
        print_message $YELLOW "Check logs: sudo frpc-manage logs"
    fi
}

# Show summary
show_summary() {
    print_message $GREEN "\n=========================================="
    print_message $GREEN "VM Setup Complete!"
    print_message $GREEN "==========================================\n"
    
    cat /root/frp-info.txt
    
    print_message $YELLOW "\nNext Steps:"
    print_message $NC "1. Test connection: sudo frpc-manage status"
    print_message $NC "2. View on VPS dashboard: http://${VPS_IP}:7500"
    print_message $NC "3. Check logs: sudo frpc-manage logs"
    print_message $NC ""
}

# Main
main() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root"
        exit 1
    fi
    
    get_vm_info
    install_frp_client
    configure_client
    create_info_file
    start_service
    show_summary
}

main
