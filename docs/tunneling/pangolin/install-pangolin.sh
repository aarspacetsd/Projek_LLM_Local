#!/bin/bash
#==============================================================================
# Pangolin VPS Installation Script
# Untuk tunneling MQTT Broker & WebSocket Server
#
# Author: Ahmad Akmal
# Deskripsi: Script otomatis untuk install Pangolin di VPS
#            dengan konfigurasi TCP tunneling untuk MQTT & WebSocket
#==============================================================================

set -e

# ===========================
# WARNA OUTPUT
# ===========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ===========================
# FUNGSI HELPER
# ===========================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Script ini harus dijalankan sebagai root!"
        log_info "Gunakan: sudo bash $0"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "Detected OS: $PRETTY_NAME"
    else
        log_error "Tidak dapat mendeteksi OS!"
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_warn "OS yang direkomendasikan: Ubuntu 20.04+ atau Debian 11+"
        read -p "Lanjutkan? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH_TYPE="amd64" ;;
        aarch64) ARCH_TYPE="arm64" ;;
        *)
            log_error "Arsitektur tidak didukung: $ARCH"
            exit 1
            ;;
    esac
    log_info "Arsitektur: $ARCH ($ARCH_TYPE)"
}

# ===========================
# STEP 1: COLLECT KONFIGURASI
# ===========================
collect_config() {
    log_header "KONFIGURASI PANGOLIN"

    # Domain
    echo -e "${CYAN}--- Domain Configuration ---${NC}"
    read -p "Masukkan base domain (contoh: example.com): " BASE_DOMAIN
    if [[ -z "$BASE_DOMAIN" ]]; then
        log_error "Domain tidak boleh kosong!"
        exit 1
    fi

    read -p "Subdomain untuk dashboard Pangolin [pangolin]: " DASHBOARD_SUB
    DASHBOARD_SUB=${DASHBOARD_SUB:-pangolin}
    DASHBOARD_DOMAIN="${DASHBOARD_SUB}.${BASE_DOMAIN}"

    echo ""
    echo -e "${CYAN}--- Email & Admin ---${NC}"
    read -p "Email untuk Let's Encrypt & Admin login: " ADMIN_EMAIL
    if [[ -z "$ADMIN_EMAIL" ]]; then
        log_error "Email tidak boleh kosong!"
        exit 1
    fi

    read -sp "Password admin (min 8 karakter): " ADMIN_PASSWORD
    echo
    if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
        log_error "Password minimal 8 karakter!"
        exit 1
    fi

    echo ""
    echo -e "${CYAN}--- MQTT Tunneling Ports ---${NC}"
    log_info "Konfigurasi port untuk MQTT Broker & WebSocket"
    echo ""

    read -p "Port MQTT Broker 1 (public) [1883]: " MQTT_PORT_1
    MQTT_PORT_1=${MQTT_PORT_1:-1883}

    read -p "Port MQTT Broker 2 (public) [1884]: " MQTT_PORT_2
    MQTT_PORT_2=${MQTT_PORT_2:-1884}

    read -p "Port WebSocket Server 1 (public) [8083]: " WS_PORT_1
    WS_PORT_1=${WS_PORT_1:-8083}

    read -p "Port WebSocket Server 2 (public) [8084]: " WS_PORT_2
    WS_PORT_2=${WS_PORT_2:-8084}

    echo ""
    echo -e "${CYAN}--- SMTP Email (Opsional) ---${NC}"
    read -p "Konfigurasi SMTP? (y/n) [n]: " SETUP_SMTP
    SETUP_SMTP=${SETUP_SMTP:-n}

    if [[ "$SETUP_SMTP" =~ ^[Yy]$ ]]; then
        read -p "SMTP Host: " SMTP_HOST
        read -p "SMTP Port [587]: " SMTP_PORT
        SMTP_PORT=${SMTP_PORT:-587}
        read -p "SMTP Username: " SMTP_USER
        read -sp "SMTP Password: " SMTP_PASS
        echo
        read -p "SMTP From address: " SMTP_FROM
    fi

    echo ""
    echo -e "${CYAN}--- CrowdSec (Opsional) ---${NC}"
    read -p "Install CrowdSec untuk keamanan tambahan? (y/n) [n]: " INSTALL_CROWDSEC
    INSTALL_CROWDSEC=${INSTALL_CROWDSEC:-n}

    # Konfirmasi
    log_header "KONFIRMASI KONFIGURASI"
    echo -e "  Base Domain       : ${GREEN}${BASE_DOMAIN}${NC}"
    echo -e "  Dashboard URL     : ${GREEN}https://${DASHBOARD_DOMAIN}${NC}"
    echo -e "  Admin Email       : ${GREEN}${ADMIN_EMAIL}${NC}"
    echo -e "  MQTT Broker 1     : ${GREEN}Port ${MQTT_PORT_1}${NC}"
    echo -e "  MQTT Broker 2     : ${GREEN}Port ${MQTT_PORT_2}${NC}"
    echo -e "  WebSocket Server 1: ${GREEN}Port ${WS_PORT_1}${NC}"
    echo -e "  WebSocket Server 2: ${GREEN}Port ${WS_PORT_2}${NC}"
    echo -e "  SMTP              : ${GREEN}$([ "$SETUP_SMTP" = "y" ] && echo "Ya" || echo "Tidak")${NC}"
    echo -e "  CrowdSec          : ${GREEN}$([ "$INSTALL_CROWDSEC" = "y" ] && echo "Ya" || echo "Tidak")${NC}"
    echo ""

    read -p "Lanjutkan instalasi? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Instalasi dibatalkan."
        exit 0
    fi
}

# ===========================
# STEP 2: INSTALL PREREQUISITES
# ===========================
install_prerequisites() {
    log_header "INSTALL PREREQUISITES"

    log_info "Memperbarui sistem..."
    apt update && apt upgrade -y

    log_info "Menginstall paket dasar..."
    apt install -y \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw \
        jq \
        htop \
        nano

    log_success "Prerequisites terinstall."
}

# ===========================
# STEP 3: INSTALL DOCKER
# ===========================
install_docker() {
    log_header "INSTALL DOCKER"

    if command -v docker &> /dev/null; then
        log_info "Docker sudah terinstall: $(docker --version)"
        read -p "Skip instalasi Docker? (y/n) [y]: " SKIP_DOCKER
        SKIP_DOCKER=${SKIP_DOCKER:-y}
        if [[ "$SKIP_DOCKER" =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    log_info "Menghapus versi Docker lama..."
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    log_info "Menambahkan Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update

    log_info "Menginstall Docker Engine..."
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    log_success "Docker terinstall: $(docker --version)"
    log_success "Docker Compose: $(docker compose version)"
}

# ===========================
# STEP 4: KONFIGURASI FIREWALL
# ===========================
configure_firewall() {
    log_header "KONFIGURASI FIREWALL"

    log_info "Mengkonfigurasi UFW..."

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # SSH
    ufw allow 22/tcp comment "SSH"

    # Pangolin - HTTP/HTTPS
    ufw allow 80/tcp comment "HTTP - Pangolin/Traefik"
    ufw allow 443/tcp comment "HTTPS - Pangolin/Traefik"

    # Pangolin - WireGuard tunnels
    ufw allow 51820/udp comment "WireGuard - Site Tunnels"
    ufw allow 21820/udp comment "WireGuard - Client Tunnels"

    # MQTT Ports
    ufw allow ${MQTT_PORT_1}/tcp comment "MQTT Broker 1"
    ufw allow ${MQTT_PORT_2}/tcp comment "MQTT Broker 2"

    # WebSocket Ports
    ufw allow ${WS_PORT_1}/tcp comment "WebSocket Server 1"
    ufw allow ${WS_PORT_2}/tcp comment "WebSocket Server 2"

    # Enable UFW
    echo "y" | ufw enable
    ufw reload

    log_success "Firewall dikonfigurasi."
    ufw status verbose
}

# ===========================
# STEP 5: SETUP PANGOLIN
# ===========================
setup_pangolin() {
    log_header "SETUP PANGOLIN"

    INSTALL_DIR="/opt/pangolin"

    log_info "Membuat direktori instalasi: ${INSTALL_DIR}"
    mkdir -p ${INSTALL_DIR}
    cd ${INSTALL_DIR}

    # Buat struktur direktori
    mkdir -p config/{db,letsencrypt,logs,traefik}

    # Buat acme.json dengan permission yang benar
    touch config/letsencrypt/acme.json
    chmod 600 config/letsencrypt/acme.json

    # ===========================
    # config.yml
    # ===========================
    log_info "Membuat config.yml..."

    SMTP_BLOCK=""
    if [[ "$SETUP_SMTP" =~ ^[Yy]$ ]]; then
        SMTP_BLOCK="
smtp:
  host: \"${SMTP_HOST}\"
  port: ${SMTP_PORT}
  user: \"${SMTP_USER}\"
  pass: \"${SMTP_PASS}\"
  from: \"${SMTP_FROM}\""
    fi

    cat > config/config.yml <<CONFIGEOF
app:
  dashboard_url: "https://${DASHBOARD_DOMAIN}"
  base_domain: "${BASE_DOMAIN}"
  log_level: "info"
  save_logs: true

users:
  server_admin:
    email: "${ADMIN_EMAIL}"
    password: "${ADMIN_PASSWORD}"

flags:
  require_email_verification: false
  disable_signup_without_invite: true
  disable_user_create_org: true
  allow_raw_resources: true
  allow_base_domain_resources: true

domains:
  - domain: "${BASE_DOMAIN}"
    cert_resolver: "letsencrypt"

gerbil:
  start_port: 51820
  base_endpoint: "${BASE_DOMAIN}"
  block_size: 24
  site_block_size: 30
  subnet_group: "100.89.137.0/20"

traefik:
  cert_resolver: "letsencrypt"
  http_entrypoint: "web"
  https_entrypoint: "websecure"
${SMTP_BLOCK}
CONFIGEOF

    # ===========================
    # traefik_config.yml
    # ===========================
    log_info "Membuat traefik_config.yml..."

    cat > config/traefik/traefik_config.yml <<TRAEFIKEOF
api:
  insecure: true
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt
    transport:
      respondingTimeouts:
        readTimeout: "0s"
  # MQTT Broker 1
  mqtt1:
    address: ":${MQTT_PORT_1}"
  # MQTT Broker 2
  mqtt2:
    address: ":${MQTT_PORT_2}"
  # WebSocket Server 1
  ws1:
    address: ":${WS_PORT_1}"
  # WebSocket Server 2
  ws2:
    address: ":${WS_PORT_2}"

certificatesResolvers:
  letsencrypt:
    acme:
      httpChallenge:
        entryPoint: web
      email: "${ADMIN_EMAIL}"
      storage: /letsencrypt/acme.json

experimental:
  plugins:
    badger:
      moduleName: github.com/fosrl/badger
      version: "v1.3.1"

providers:
  file:
    filename: /etc/traefik/dynamic_config.yml
    watch: true

log:
  level: "INFO"
TRAEFIKEOF

    # ===========================
    # dynamic_config.yml
    # ===========================
    log_info "Membuat dynamic_config.yml..."

    cat > config/traefik/dynamic_config.yml <<DYNAMICEOF
http:
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
    badger:
      plugin:
        badger:
          disableForwardAuth: true

  routers:
    # HTTP to HTTPS redirect
    main-app-router-redirect:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`)"
      service: next-service
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
        - badger

    # Next.js router
    next-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`) && !PathPrefix(\`/api/v1\`)"
      service: next-service
      entryPoints:
        - websecure
      middlewares:
        - badger
      tls:
        certResolver: letsencrypt

    # API router
    api-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`) && PathPrefix(\`/api/v1\`)"
      service: api-service
      entryPoints:
        - websecure
      middlewares:
        - badger
      tls:
        certResolver: letsencrypt

    # WebSocket router
    ws-router:
      rule: "Host(\`${DASHBOARD_DOMAIN}\`)"
      service: api-service
      entryPoints:
        - websecure
      middlewares:
        - badger
      tls:
        certResolver: letsencrypt

  services:
    next-service:
      loadBalancer:
        servers:
          - url: "http://pangolin:3002"
    api-service:
      loadBalancer:
        servers:
          - url: "http://pangolin:3001"
DYNAMICEOF

    # ===========================
    # docker-compose.yml
    # ===========================
    log_info "Membuat docker-compose.yml..."

    cat > docker-compose.yml <<COMPOSEEOF
name: pangolin

services:
  pangolin:
    image: docker.io/fosrl/pangolin:latest
    container_name: pangolin
    restart: unless-stopped
    volumes:
      - ./config:/app/config
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/v1/"]
      interval: "10s"
      timeout: "10s"
      retries: 15

  gerbil:
    image: docker.io/fosrl/gerbil:latest
    container_name: gerbil
    restart: unless-stopped
    depends_on:
      pangolin:
        condition: service_healthy
    command:
      - --reachableAt=http://gerbil:3004
      - --generateAndSaveKeyTo=/var/config/key
      - --remoteConfig=http://pangolin:3001/api/v1/
    volumes:
      - ./config/:/var/config
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    ports:
      - 51820:51820/udp
      - 21820:21820/udp
      - 443:443
      - 80:80
      # MQTT Ports
      - ${MQTT_PORT_1}:${MQTT_PORT_1}
      - ${MQTT_PORT_2}:${MQTT_PORT_2}
      # WebSocket Ports
      - ${WS_PORT_1}:${WS_PORT_1}
      - ${WS_PORT_2}:${WS_PORT_2}

  traefik:
    image: docker.io/traefik:v3.6
    container_name: traefik
    restart: unless-stopped
    network_mode: service:gerbil
    depends_on:
      pangolin:
        condition: service_healthy
    command:
      - --configFile=/etc/traefik/traefik_config.yml
    volumes:
      - ./config/traefik/traefik_config.yml:/etc/traefik/traefik_config.yml
      - ./config/traefik/dynamic_config.yml:/etc/traefik/dynamic_config.yml
      - ./config/letsencrypt:/letsencrypt
COMPOSEEOF

    log_success "Konfigurasi Pangolin dibuat di ${INSTALL_DIR}"
}

# ===========================
# STEP 6: START PANGOLIN
# ===========================
start_pangolin() {
    log_header "MENJALANKAN PANGOLIN"

    cd /opt/pangolin

    log_info "Pulling Docker images..."
    docker compose pull

    log_info "Starting containers..."
    docker compose up -d

    log_info "Menunggu container healthy..."
    sleep 10

    # Check status
    docker compose ps

    log_success "Pangolin berjalan!"
}

# ===========================
# STEP 7: BUAT NEWT COMPOSE TEMPLATE
# ===========================
create_newt_template() {
    log_header "MEMBUAT TEMPLATE NEWT (untuk server lokal)"

    mkdir -p /opt/pangolin/newt-templates

    cat > /opt/pangolin/newt-templates/docker-compose.newt.yml <<'NEWTEOF'
# ================================================================
# TEMPLATE: Newt Client Docker Compose
# Jalankan ini di server lokal yang memiliki MQTT Broker
#
# INSTRUKSI:
# 1. Login ke Pangolin Dashboard
# 2. Buat Site baru -> copy NEWT_ID dan NEWT_SECRET
# 3. Ganti nilai di bawah dengan credentials dari Pangolin
# 4. Jalankan: docker compose -f docker-compose.newt.yml up -d
# ================================================================

services:
  newt:
    image: fosrl/newt:latest
    container_name: newt
    restart: unless-stopped
    environment:
      - PANGOLIN_ENDPOINT=https://GANTI_DENGAN_DASHBOARD_DOMAIN
      - NEWT_ID=GANTI_DENGAN_NEWT_ID
      - NEWT_SECRET=GANTI_DENGAN_NEWT_SECRET
NEWTEOF

    log_success "Template Newt dibuat di /opt/pangolin/newt-templates/"
}

# ===========================
# STEP 8: BUAT INFO FILE
# ===========================
create_info_file() {
    log_header "MEMBUAT FILE INFORMASI"

    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "UNKNOWN")

    cat > /opt/pangolin/INSTALLATION_INFO.txt <<INFOEOF
================================================================
  PANGOLIN INSTALLATION INFO
  Tanggal: $(date)
================================================================

DASHBOARD URL  : https://${DASHBOARD_DOMAIN}
ADMIN EMAIL    : ${ADMIN_EMAIL}
VPS IP         : ${VPS_IP}

PORTS YANG TERBUKA:
  - 80/tcp    : HTTP (redirect ke HTTPS)
  - 443/tcp   : HTTPS (Pangolin Dashboard & Resources)
  - 51820/udp : WireGuard Site Tunnels
  - 21820/udp : WireGuard Client Tunnels
  - ${MQTT_PORT_1}/tcp  : MQTT Broker 1
  - ${MQTT_PORT_2}/tcp  : MQTT Broker 2
  - ${WS_PORT_1}/tcp  : WebSocket Server 1
  - ${WS_PORT_2}/tcp  : WebSocket Server 2

DNS RECORDS YANG DIBUTUHKAN:
  Type: A | Name: *               | Value: ${VPS_IP}
  Type: A | Name: ${DASHBOARD_SUB} | Value: ${VPS_IP}
  Type: A | Name: @               | Value: ${VPS_IP} (opsional)

FILE LOKASI:
  - Konfigurasi : /opt/pangolin/config/
  - Docker Compose : /opt/pangolin/docker-compose.yml
  - Newt Template : /opt/pangolin/newt-templates/
  - SSL Certs : /opt/pangolin/config/letsencrypt/

PERINTAH BERGUNA:
  - Status    : cd /opt/pangolin && docker compose ps
  - Logs      : cd /opt/pangolin && docker compose logs -f
  - Restart   : cd /opt/pangolin && docker compose restart
  - Stop      : cd /opt/pangolin && docker compose down
  - Update    : cd /opt/pangolin && docker compose pull && docker compose up -d

================================================================
INFOEOF

    log_success "Info file dibuat: /opt/pangolin/INSTALLATION_INFO.txt"
}

# ===========================
# STEP 9: POST-INSTALL SUMMARY
# ===========================
post_install_summary() {
    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "UNKNOWN")

    log_header "INSTALASI SELESAI!"

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           PANGOLIN BERHASIL DIINSTALL!                  ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Dashboard : ${CYAN}https://${DASHBOARD_DOMAIN}${NC}"
    echo -e "${GREEN}║${NC}  Setup URL : ${CYAN}https://${DASHBOARD_DOMAIN}/auth/initial-setup${NC}"
    echo -e "${GREEN}║${NC}  VPS IP    : ${CYAN}${VPS_IP}${NC}"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  ${YELLOW}LANGKAH SELANJUTNYA:${NC}"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  1. Pastikan DNS records sudah dikonfigurasi:"
    echo -e "${GREEN}║${NC}     - A record: *  -> ${VPS_IP}"
    echo -e "${GREEN}║${NC}     - A record: ${DASHBOARD_SUB} -> ${VPS_IP}"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  2. Buka ${CYAN}https://${DASHBOARD_DOMAIN}/auth/initial-setup${NC}"
    echo -e "${GREEN}║${NC}     untuk menyelesaikan setup awal."
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  3. Buat Site & konfigurasi Newt di server lokal"
    echo -e "${GREEN}║${NC}     (lihat INSTRUKSI.md untuk detail lengkap)"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  4. Buat Resources untuk MQTT & WebSocket"
    echo -e "${GREEN}║${NC}     menggunakan Raw TCP Resource di dashboard"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ===========================
# MAIN
# ===========================
main() {
    log_header "PANGOLIN VPS INSTALLER"
    echo -e "  ${CYAN}Tunneling untuk MQTT Broker & WebSocket Server${NC}"
    echo ""

    check_root
    check_os
    check_arch
    collect_config
    install_prerequisites
    install_docker
    configure_firewall
    setup_pangolin
    start_pangolin
    create_newt_template
    create_info_file
    post_install_summary
}

main "$@"
