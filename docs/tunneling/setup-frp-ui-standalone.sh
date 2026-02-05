#!/bin/bash

# FRP Simple UI - Standalone PHP Server
# No nginx needed!
# Author: Ahmad Akmal

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_message $RED "Error: Run as root"
        exit 1
    fi
}

# Create standalone UI
create_standalone_ui() {
    print_message $BLUE "Creating standalone FRP UI..."
    
    mkdir -p /opt/frp-ui
    
    cat > /opt/frp-ui/index.php << 'PHPEOF'
<?php
// Standalone FRP Config Editor
session_start();

$config_file = '/etc/frp/frpc.toml';
$auth_user = 'admin';
$auth_pass = 'admin123';

// Authentication
if (!isset($_SESSION['auth'])) {
    if (isset($_POST['user']) && isset($_POST['pass'])) {
        if ($_POST['user'] === $auth_user && $_POST['pass'] === $auth_pass) {
            $_SESSION['auth'] = true;
            header('Location: index.php');
            exit;
        }
        $error = "Invalid credentials!";
    }
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>FRP UI - Login</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            .login-box { 
                background: white;
                padding: 40px;
                border-radius: 16px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                width: 100%;
                max-width: 400px;
            }
            h2 { 
                color: #333;
                margin-bottom: 10px;
                font-size: 28px;
            }
            .subtitle {
                color: #666;
                margin-bottom: 30px;
                font-size: 14px;
            }
            input { 
                width: 100%;
                padding: 12px;
                margin: 10px 0;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                font-size: 14px;
                transition: border 0.3s;
            }
            input:focus {
                outline: none;
                border-color: #667eea;
            }
            button { 
                width: 100%;
                padding: 12px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border: none;
                border-radius: 8px;
                cursor: pointer;
                font-size: 16px;
                font-weight: 600;
                margin-top: 10px;
                transition: transform 0.2s;
            }
            button:hover { 
                transform: translateY(-2px);
            }
            .error { 
                color: #e74c3c;
                background: #fadbd8;
                padding: 12px;
                border-radius: 8px;
                margin-bottom: 20px;
                font-size: 14px;
            }
            .logo {
                text-align: center;
                font-size: 48px;
                margin-bottom: 20px;
            }
        </style>
    </head>
    <body>
        <div class="login-box">
            <div class="logo">🔧</div>
            <h2>FRP Config Editor</h2>
            <p class="subtitle">Manage your tunneling configuration</p>
            <?php if (isset($error)) echo "<div class='error'>$error</div>"; ?>
            <form method="POST">
                <input type="text" name="user" placeholder="Username" required autofocus>
                <input type="password" name="pass" placeholder="Password" required>
                <button type="submit">Login</button>
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: index.php');
    exit;
}

// Handle save
$message = '';
if (isset($_POST['config'])) {
    file_put_contents($config_file, $_POST['config']);
    exec('systemctl restart frpc 2>&1', $output, $return);
    if ($return === 0) {
        $message = "✓ Configuration saved and service restarted!";
        $msg_type = "success";
    } else {
        $message = "⚠ Configuration saved but failed to restart service";
        $msg_type = "warning";
    }
}

// Read config
$config = file_exists($config_file) ? file_get_contents($config_file) : "# Config file not found\n# Please create /etc/frp/frpc.toml";
$service_status = trim(shell_exec('systemctl is-active frpc 2>/dev/null') ?? 'unknown');
$service_enabled = trim(shell_exec('systemctl is-enabled frpc 2>/dev/null') ?? 'unknown');

// Get system info
$public_ip = trim(shell_exec('curl -s ifconfig.me 2>/dev/null') ?? 'N/A');
$frp_version = trim(shell_exec('/opt/frp/frpc -v 2>/dev/null | head -1') ?? 'N/A');
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FRP Config Editor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f7fa;
            padding: 20px;
        }
        .container { 
            max-width: 1400px;
            margin: 0 auto;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 16px;
            margin-bottom: 20px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 32px;
            margin-bottom: 10px;
        }
        .header-info {
            display: flex;
            gap: 30px;
            flex-wrap: wrap;
            margin-top: 15px;
            font-size: 14px;
            opacity: 0.9;
        }
        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 10px;
        }
        .status-active { background: #2ecc71; color: white; }
        .status-inactive { background: #e74c3c; color: white; }
        .status-unknown { background: #95a5a6; color: white; }
        
        .grid {
            display: grid;
            grid-template-columns: 300px 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .sidebar {
            background: white;
            padding: 20px;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            height: fit-content;
        }
        .sidebar h3 {
            margin-bottom: 15px;
            color: #333;
        }
        .sidebar-item {
            padding: 12px;
            margin: 8px 0;
            background: #f8f9fa;
            border-radius: 8px;
            font-size: 14px;
        }
        .sidebar-item strong {
            display: block;
            color: #667eea;
            margin-bottom: 4px;
        }
        
        .main-content {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
        }
        
        .message {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 14px;
            animation: slideIn 0.3s ease;
        }
        .message.success { background: #d4edda; color: #155724; border-left: 4px solid #28a745; }
        .message.warning { background: #fff3cd; color: #856404; border-left: 4px solid #ffc107; }
        
        @keyframes slideIn {
            from { transform: translateY(-20px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        
        .editor-toolbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding-bottom: 15px;
            border-bottom: 2px solid #e0e0e0;
        }
        .editor-toolbar h2 {
            color: #333;
            font-size: 20px;
        }
        
        textarea {
            width: 100%;
            height: 500px;
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            font-size: 13px;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            resize: vertical;
            line-height: 1.6;
        }
        textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .button-group {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        button {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.2s;
        }
        .btn-save {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            flex: 1;
        }
        .btn-save:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        .btn-reload {
            background: #f8f9fa;
            color: #333;
            border: 2px solid #e0e0e0;
        }
        .btn-reload:hover {
            background: #e9ecef;
        }
        .btn-logout {
            background: #e74c3c;
            color: white;
        }
        .btn-logout:hover {
            background: #c0392b;
        }
        
        .quick-actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
            margin-bottom: 20px;
        }
        .quick-action {
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            text-align: center;
            cursor: pointer;
            transition: all 0.2s;
            border: 2px solid transparent;
        }
        .quick-action:hover {
            background: #667eea;
            color: white;
            border-color: #667eea;
            transform: translateY(-2px);
        }
        .quick-action-icon {
            font-size: 24px;
            margin-bottom: 8px;
        }
        
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
            .button-group {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 FRP Configuration Editor</h1>
            <div class="header-info">
                <div>
                    <strong>Service Status:</strong>
                    <span class="status-badge status-<?php echo $service_status === 'active' ? 'active' : ($service_status === 'inactive' ? 'inactive' : 'unknown'); ?>">
                        <?php echo strtoupper($service_status); ?>
                    </span>
                </div>
                <div><strong>Auto-start:</strong> <?php echo strtoupper($service_enabled); ?></div>
                <div><strong>Public IP:</strong> <?php echo $public_ip; ?></div>
                <div><strong>Version:</strong> <?php echo $frp_version; ?></div>
            </div>
        </div>
        
        <div class="grid">
            <div class="sidebar">
                <h3>Quick Commands</h3>
                <div class="quick-actions">
                    <div class="quick-action" onclick="if(confirm('Restart FRP service?')) window.location.href='?action=restart'">
                        <div class="quick-action-icon">🔄</div>
                        <div>Restart</div>
                    </div>
                    <div class="quick-action" onclick="window.location.href='?action=logs'">
                        <div class="quick-action-icon">📋</div>
                        <div>View Logs</div>
                    </div>
                    <div class="quick-action" onclick="window.location.href='?action=status'">
                        <div class="quick-action-icon">📊</div>
                        <div>Status</div>
                    </div>
                    <div class="quick-action" onclick="if(confirm('Logout?')) window.location.href='?logout=1'">
                        <div class="quick-action-icon">🚪</div>
                        <div>Logout</div>
                    </div>
                </div>
                
                <h3 style="margin-top: 20px;">System Info</h3>
                <div class="sidebar-item">
                    <strong>Config File</strong>
                    /etc/frp/frpc.toml
                </div>
                <div class="sidebar-item">
                    <strong>Log File</strong>
                    /var/log/frp/frpc.log
                </div>
                <div class="sidebar-item">
                    <strong>Admin Port</strong>
                    http://localhost:7400
                </div>
            </div>
            
            <div class="main-content">
                <?php if ($message): ?>
                    <div class="message <?php echo $msg_type; ?>"><?php echo $message; ?></div>
                <?php endif; ?>
                
                <div class="editor-toolbar">
                    <h2>Configuration Editor</h2>
                </div>
                
                <form method="POST">
                    <textarea name="config" spellcheck="false"><?php echo htmlspecialchars($config); ?></textarea>
                    <div class="button-group">
                        <button type="submit" class="btn-save">💾 Save & Restart</button>
                        <button type="button" class="btn-reload" onclick="location.reload()">🔄 Reload</button>
                        <button type="button" class="btn-logout" onclick="if(confirm('Logout?')) location.href='?logout=1'">🚪 Logout</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</body>
</html>
PHPEOF

    chmod 644 /opt/frp-ui/index.php
    
    print_message $GREEN "✓ Standalone UI created at /opt/frp-ui"
}

# Create systemd service for auto-start
create_service() {
    print_message $BLUE "Creating systemd service..."
    
    cat > /etc/systemd/system/frp-ui.service << 'SERVICEEOF'
[Unit]
Description=FRP Web UI (Standalone PHP Server)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/frp-ui
ExecStart=/usr/bin/php -S 0.0.0.0:7888 -t /opt/frp-ui
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload
    print_message $GREEN "✓ Service created"
}

# Create management script
create_manager() {
    cat > /usr/local/bin/frp-ui << 'MANAGEREOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start frp-ui
        echo "FRP UI started at http://$(hostname -I | awk '{print $1}'):7888"
        ;;
    stop)
        systemctl stop frp-ui
        ;;
    restart)
        systemctl restart frp-ui
        ;;
    status)
        systemctl status frp-ui
        ;;
    logs)
        journalctl -u frp-ui -f
        ;;
    *)
        echo "Usage: frp-ui {start|stop|restart|status|logs}"
        ;;
esac
MANAGEREOF
    
    chmod +x /usr/local/bin/frp-ui
}

show_instructions() {
    local ip=$(hostname -I | awk '{print $1}')
    
    print_message $GREEN "\n=========================================="
    print_message $GREEN "FRP Standalone UI Installed!"
    print_message $GREEN "==========================================\n"
    
    print_message $YELLOW "Access UI:"
    print_message $BLUE "  http://${ip}:7888"
    print_message $BLUE "  http://localhost:7888 (from server)"
    print_message $NC ""
    print_message $YELLOW "Login:"
    print_message $BLUE "  Username: admin"
    print_message $BLUE "  Password: admin123"
    print_message $NC ""
    print_message $RED "⚠ IMPORTANT: Change password in /opt/frp-ui/index.php"
    print_message $NC ""
    print_message $YELLOW "Management:"
    print_message $BLUE "  frp-ui start    - Start UI server"
    print_message $BLUE "  frp-ui stop     - Stop UI server"
    print_message $BLUE "  frp-ui restart  - Restart UI server"
    print_message $BLUE "  frp-ui status   - Check status"
    print_message $BLUE "  frp-ui logs     - View logs"
    print_message $NC ""
    print_message $YELLOW "Starting service..."
}

main() {
    check_root
    create_standalone_ui
    create_service
    create_manager
    show_instructions
    
    systemctl start frp-ui
    systemctl enable frp-ui
    
    sleep 2
    if systemctl is-active --quiet frp-ui; then
        print_message $GREEN "✓ UI is running!"
    else
        print_message $RED "✗ Failed to start. Check: frp-ui status"
    fi
}

main
