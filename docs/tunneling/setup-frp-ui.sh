#!/bin/bash

# FRPMgr - Web-based FRP Management UI
# This provides a better UI to manage FRP tunnels
# Author: Ahmad Akmal
# Version: 1.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_message $RED "Error: This script must be run as root"
        exit 1
    fi
}

# Install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        print_message $GREEN "Docker already installed"
        return
    fi
    
    print_message $BLUE "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
    print_message $GREEN "Docker installed successfully"
}

# Install FRPMgr
install_frpmgr() {
    print_message $BLUE "Installing FRPMgr Web UI..."
    
    # Create directory
    mkdir -p /opt/frpmgr
    cd /opt/frpmgr
    
    # Create docker-compose file
    cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  frpmgr:
    image: stilleshan/frpc
    container_name: frpmgr
    restart: unless-stopped
    network_mode: host
    volumes:
      - /etc/frp:/etc/frp
      - /var/log/frp:/var/log/frp
    environment:
      - TZ=Asia/Jakarta
    command: >
      /bin/sh -c "
      if [ ! -f /etc/frp/frpc.toml ]; then
        echo 'FRP config not found. Please configure first.';
        sleep infinity;
      else
        /usr/local/bin/frpc -c /etc/frp/frpc.toml;
      fi"

  frpmgr-ui:
    image: koalazak/frpc-web-ui
    container_name: frpmgr-ui
    restart: unless-stopped
    ports:
      - "7401:7401"
    volumes:
      - /etc/frp:/config
    environment:
      - FRP_CONFIG_PATH=/config/frpc.toml
      - FRP_ADMIN_PORT=7400
      - UI_PORT=7401
      - UI_USER=admin
      - UI_PASSWORD=admin123
    depends_on:
      - frpmgr
DOCKEREOF

    print_message $GREEN "FRPMgr configuration created"
}

# Alternative: Install frp-panel (Better UI)
install_frp_panel() {
    print_message $BLUE "Installing FRP-Panel (Advanced UI)..."
    
    mkdir -p /opt/frp-panel
    cd /opt/frp-panel
    
    # Download latest release
    PANEL_VERSION="0.48.1"
    wget -q --show-progress https://github.com/VaalaCat/frp-panel/releases/download/v${PANEL_VERSION}/frp-panel-linux-amd64.tar.gz
    tar -xzf frp-panel-linux-amd64.tar.gz
    chmod +x frpp-server
    
    # Create config
    cat > config.yaml << 'PANELEOF'
server:
  port: 7800
  secret: "change-this-secret-key"
  
database:
  type: sqlite
  path: ./frp-panel.db

admin:
  username: admin
  password: admin123
  email: admin@localhost

frp:
  config_path: /etc/frp
  log_path: /var/log/frp
PANELEOF

    # Create systemd service
    cat > /etc/systemd/system/frp-panel.service << 'SERVICEEOF'
[Unit]
Description=FRP Panel Web UI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/frp-panel
ExecStart=/opt/frp-panel/frpp-server -c /opt/frp-panel/config.yaml
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload
    systemctl enable frp-panel
    systemctl start frp-panel
    
    print_message $GREEN "FRP-Panel installed successfully"
    print_message $YELLOW "Access at: http://localhost:7800"
    print_message $YELLOW "Default login: admin / admin123"
}

# Install simple web-based config editor
install_simple_ui() {
    print_message $BLUE "Installing Simple Config Web Editor..."
    
    mkdir -p /var/www/frp-config
    
    # Create simple PHP-based config editor
    cat > /var/www/frp-config/index.php << 'PHPEOF'
<?php
// Simple FRP Config Editor
session_start();

$config_file = '/etc/frp/frpc.toml';
$auth_user = 'admin';
$auth_pass = 'admin123'; // Change this!

// Simple authentication
if (!isset($_SESSION['authenticated'])) {
    if (isset($_POST['username']) && isset($_POST['password'])) {
        if ($_POST['username'] === $auth_user && $_POST['password'] === $auth_pass) {
            $_SESSION['authenticated'] = true;
        } else {
            $error = "Invalid credentials";
        }
    }
    
    if (!isset($_SESSION['authenticated'])) {
        ?>
        <!DOCTYPE html>
        <html>
        <head>
            <title>FRP Config Editor - Login</title>
            <style>
                body { font-family: Arial, sans-serif; background: #f5f5f5; padding: 50px; }
                .login { max-width: 400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; }
                button { width: 100%; padding: 10px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
                button:hover { background: #0056b3; }
                .error { color: red; padding: 10px; background: #ffe6e6; border-radius: 4px; margin: 10px 0; }
            </style>
        </head>
        <body>
            <div class="login">
                <h2>FRP Config Editor</h2>
                <?php if (isset($error)) echo "<div class='error'>$error</div>"; ?>
                <form method="POST">
                    <input type="text" name="username" placeholder="Username" required>
                    <input type="password" name="password" placeholder="Password" required>
                    <button type="submit">Login</button>
                </form>
            </div>
        </body>
        </html>
        <?php
        exit;
    }
}

// Handle logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: index.php');
    exit;
}

// Handle save
if (isset($_POST['config'])) {
    file_put_contents($config_file, $_POST['config']);
    $message = "Configuration saved! Restart FRP client to apply changes.";
    exec('systemctl restart frpc 2>&1', $output, $return);
    if ($return === 0) {
        $message .= " Service restarted successfully.";
    }
}

// Read current config
$config = file_get_contents($config_file);
$service_status = shell_exec('systemctl is-active frpc');
?>
<!DOCTYPE html>
<html>
<head>
    <title>FRP Config Editor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        textarea { width: 100%; height: 400px; font-family: monospace; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
        button { padding: 10px 20px; margin: 10px 5px 0 0; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; }
        .save { background: #28a745; color: white; }
        .save:hover { background: #218838; }
        .restart { background: #17a2b8; color: white; }
        .restart:hover { background: #138496; }
        .logout { background: #dc3545; color: white; }
        .logout:hover { background: #c82333; }
        .message { padding: 10px; background: #d4edda; color: #155724; border: 1px solid #c3e6cb; border-radius: 4px; margin: 10px 0; }
        .status { display: inline-block; padding: 5px 10px; border-radius: 4px; font-size: 12px; margin-left: 10px; }
        .status.active { background: #d4edda; color: #155724; }
        .status.inactive { background: #f8d7da; color: #721c24; }
        .info { background: #d1ecf1; color: #0c5460; padding: 15px; border-radius: 4px; margin: 15px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>
            FRP Configuration Editor
            <span class="status <?php echo trim($service_status) === 'active' ? 'active' : 'inactive'; ?>">
                <?php echo trim($service_status) === 'active' ? 'Running' : 'Stopped'; ?>
            </span>
            <a href="?logout=1" style="float:right"><button class="logout">Logout</button></a>
        </h1>
        
        <?php if (isset($message)) echo "<div class='message'>$message</div>"; ?>
        
        <div class="info">
            <strong>Quick Actions:</strong><br>
            • Edit config below and click Save<br>
            • Service will auto-restart after save<br>
            • Check <code>systemctl status frpc</code> for details<br>
            • View logs: <code>tail -f /var/log/frp/frpc.log</code>
        </div>
        
        <form method="POST">
            <textarea name="config"><?php echo htmlspecialchars($config); ?></textarea>
            <button type="submit" class="save">Save & Restart</button>
            <button type="button" class="restart" onclick="location.reload()">Reload</button>
        </form>
    </div>
</body>
</html>
PHPEOF

    # Install Nginx and PHP
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y nginx php-fpm
    elif command -v yum &> /dev/null; then
        yum install -y nginx php-fpm
    fi
    
    # Configure Nginx
    cat > /etc/nginx/sites-available/frp-config << 'NGINXEOF'
server {
    listen 7888;
    server_name _;
    root /var/www/frp-config;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
NGINXEOF

    ln -sf /etc/nginx/sites-available/frp-config /etc/nginx/sites-enabled/
    systemctl restart nginx
    systemctl restart php*-fpm
    
    print_message $GREEN "Simple UI installed successfully"
    print_message $YELLOW "Access at: http://localhost:7888"
    print_message $YELLOW "Default login: admin / admin123"
    print_message $RED "IMPORTANT: Change password in /var/www/frp-config/index.php"
}

# Main menu
show_menu() {
    print_message $BLUE "\n=========================================="
    print_message $BLUE "FRP Web UI Installation"
    print_message $BLUE "==========================================\n"
    
    print_message $YELLOW "Choose UI solution:"
    print_message $NC "1) Simple Config Editor (Lightweight PHP-based)"
    print_message $NC "2) FRPMgr (Docker-based with monitoring)"
    print_message $NC "3) FRP-Panel (Advanced features - Experimental)"
    print_message $NC "4) Show FRP native dashboard info"
    print_message $NC "5) Exit"
    print_message $NC ""
    
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            install_simple_ui
            ;;
        2)
            install_docker
            install_frpmgr
            print_message $YELLOW "Start with: cd /opt/frpmgr && docker-compose up -d"
            ;;
        3)
            install_frp_panel
            ;;
        4)
            print_message $BLUE "FRP Native Dashboard:"
            print_message $NC "Server: http://SERVER_IP:7500 (configured in frps.toml)"
            print_message $NC "Client: http://localhost:7400 (configured in frpc.toml)"
            print_message $NC ""
            print_message $YELLOW "Features: Read-only monitoring"
            print_message $NC "- View connected clients"
            print_message $NC "- See active proxies"
            print_message $NC "- Monitor traffic"
            ;;
        5)
            exit 0
            ;;
        *)
            print_message $RED "Invalid choice"
            exit 1
            ;;
    esac
}

# Final instructions
show_instructions() {
    print_message $GREEN "\n=========================================="
    print_message $GREEN "Installation Complete!"
    print_message $GREEN "==========================================\n"
    
    print_message $YELLOW "Security Notes:"
    print_message $RED "⚠ Change default passwords immediately"
    print_message $RED "⚠ Use firewall to restrict access"
    print_message $RED "⚠ Consider using reverse proxy with SSL"
    print_message $NC ""
}

# Main
main() {
    check_root
    show_menu
    show_instructions
}

main
