#!/bin/bash

# Nginx Troubleshooting Script
# Run this to diagnose and fix nginx issues

echo "=========================================="
echo "Nginx Troubleshooting"
echo "=========================================="
echo ""

# Check if nginx is installed
echo "1. Checking Nginx installation..."
if command -v nginx &> /dev/null; then
    echo "✓ Nginx is installed"
    nginx -v
else
    echo "✗ Nginx is not installed"
    exit 1
fi
echo ""

# Test nginx configuration
echo "2. Testing Nginx configuration..."
nginx -t
NGINX_TEST_EXIT=$?
echo ""

if [ $NGINX_TEST_EXIT -ne 0 ]; then
    echo "✗ Nginx configuration has errors!"
    echo ""
    echo "Common fixes:"
    echo "============================================"
    echo ""
    
    # Check for common issues
    echo "Checking for common issues..."
    echo ""
    
    # Issue 1: Port already in use
    echo "• Checking if ports are already in use..."
    netstat -tlnp | grep -E ':80 |:443 |:7888 |:7500 ' || ss -tlnp | grep -E ':80 |:443 |:7888 |:7500 '
    echo ""
    
    # Issue 2: sites-enabled symlink issues
    echo "• Checking sites-enabled..."
    ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "sites-enabled directory not found"
    echo ""
    
    # Issue 3: Duplicate server blocks
    echo "• Checking for duplicate server blocks..."
    grep -r "listen 80" /etc/nginx/sites-enabled/ 2>/dev/null | head -5
    echo ""
    
    # Issue 4: Missing directories
    echo "• Checking required directories..."
    [ -d /var/www/frp-config ] && echo "✓ /var/www/frp-config exists" || echo "✗ /var/www/frp-config missing"
    [ -d /etc/nginx/sites-available ] && echo "✓ /etc/nginx/sites-available exists" || echo "✗ /etc/nginx/sites-available missing"
    [ -d /etc/nginx/sites-enabled ] && echo "✓ /etc/nginx/sites-enabled exists" || echo "✗ /etc/nginx/sites-enabled missing"
    echo ""
    
    echo "=========================================="
    echo "Automated Fix Options:"
    echo "=========================================="
    echo ""
    echo "Choose a fix:"
    echo "1) Remove conflicting FRP configs and retry"
    echo "2) Disable all custom sites and use default only"
    echo "3) Show detailed error log"
    echo "4) Manually fix (show config files)"
    echo "5) Completely remove nginx configs and reinstall"
    echo ""
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            echo "Removing FRP nginx configs..."
            rm -f /etc/nginx/sites-enabled/frp-* 2>/dev/null
            rm -f /etc/nginx/sites-available/frp-* 2>/dev/null
            echo "Testing configuration..."
            nginx -t
            if [ $? -eq 0 ]; then
                echo "✓ Configuration fixed! Restarting nginx..."
                systemctl restart nginx
            else
                echo "Still has errors. Check option 3 for details."
            fi
            ;;
        2)
            echo "Disabling all custom sites..."
            rm -f /etc/nginx/sites-enabled/* 2>/dev/null
            ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
            echo "Testing configuration..."
            nginx -t
            if [ $? -eq 0 ]; then
                echo "✓ Configuration fixed! Restarting nginx..."
                systemctl restart nginx
            fi
            ;;
        3)
            echo "Detailed error log:"
            echo "===================="
            nginx -t 2>&1
            echo ""
            echo "Last 20 lines of error log:"
            echo "============================"
            tail -20 /var/log/nginx/error.log
            ;;
        4)
            echo "Nginx configuration files:"
            echo "=========================="
            echo ""
            echo "Main config:"
            cat /etc/nginx/nginx.conf
            echo ""
            echo "Sites enabled:"
            ls -la /etc/nginx/sites-enabled/
            echo ""
            echo "Check each file for errors with:"
            echo "nano /etc/nginx/sites-enabled/FILENAME"
            ;;
        5)
            echo "⚠️  This will remove all nginx configs!"
            read -p "Are you sure? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                systemctl stop nginx
                rm -rf /etc/nginx/sites-enabled/*
                rm -rf /etc/nginx/sites-available/frp-*
                rm -rf /etc/nginx/conf.d/frp-*
                ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
                nginx -t
                systemctl start nginx
                echo "✓ Nginx reset to default configuration"
            fi
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
else
    echo "✓ Nginx configuration is valid!"
    echo ""
    echo "3. Checking Nginx service status..."
    systemctl status nginx --no-pager
    echo ""
    echo "4. Checking if Nginx is running..."
    if systemctl is-active --quiet nginx; then
        echo "✓ Nginx is running"
    else
        echo "✗ Nginx is not running"
        echo ""
        read -p "Start Nginx now? [Y/n]: " start_nginx
        if [[ ! "$start_nginx" =~ ^[Nn]$ ]]; then
            systemctl start nginx
            if systemctl is-active --quiet nginx; then
                echo "✓ Nginx started successfully"
            else
                echo "✗ Failed to start Nginx"
                echo "Check logs: journalctl -xeu nginx.service"
            fi
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Quick Diagnostic Summary:"
echo "=========================================="
echo ""
echo "Nginx version: $(nginx -v 2>&1)"
echo "Config test: $(nginx -t 2>&1 | grep -q 'successful' && echo '✓ OK' || echo '✗ FAILED')"
echo "Service status: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo ""
echo "Listening ports:"
netstat -tlnp 2>/dev/null | grep nginx || ss -tlnp 2>/dev/null | grep nginx || echo "Not running"
echo ""
echo "To view logs: journalctl -xeu nginx.service"
echo "To restart: systemctl restart nginx"
echo ""
