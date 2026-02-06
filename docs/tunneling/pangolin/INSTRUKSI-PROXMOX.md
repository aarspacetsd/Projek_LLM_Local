# Panduan Lengkap: Pangolin VPS Tunneling untuk VM di Proxmox

## Arsitektur Sistem (Proxmox Edition)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          INTERNET / CLIENT                          │
│                                                                     │
│   IoT Device ──► mqtt.domain.com:1883   (MQTT Broker 1 - VM1)      │
│   IoT Device ──► mqtt2.domain.com:1884  (MQTT Broker 2 - VM2)      │
│   Browser    ──► ws.domain.com:8083     (WebSocket Srv 1 - VM3)     │
│   Browser    ──► ws2.domain.com:8084    (WebSocket Srv 2 - VM4)     │
│   Browser    ──► app.domain.com         (HTTP App - VM lain)        │
│   Admin      ──► pangolin.domain.com    (Dashboard UI)              │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                ┌───────────▼───────────┐
                │    VPS (Public IP)     │
                │                       │
                │  ┌─────────────────┐  │
                │  │   Pangolin +    │  │
                │  │   Traefik +     │  │
                │  │   Gerbil        │  │
                │  │   (Docker)      │  │
                │  └────────┬────────┘  │
                │      Port 51820/UDP   │
                └───────────┬───────────┘
                            │
              ══════════════╪══════════════
               Encrypted WireGuard Tunnel
              ══════════════╪══════════════
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│                      PROXMOX HOST (Lokal / Homelab)                 │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              VM-GATEWAY (Debian/Ubuntu Minimal)              │    │
│  │                                                             │    │
│  │  ┌──────────┐    Newt membuat tunnel WireGuard              │    │
│  │  │   Newt   │    ke VPS. Semua traffic dari VPS             │    │
│  │  │ (Docker) │    masuk melalui VM ini, lalu                 │    │
│  │  └────┬─────┘    diteruskan ke VM lain via                  │    │
│  │       │          jaringan internal Proxmox                  │    │
│  │       │                                                     │    │
│  │  vmbr0: 192.168.1.50 (Bridge ke LAN)                       │    │
│  └───────┬─────────────────────────────────────────────────────┘    │
│          │  Proxmox Internal Network (vmbr0 / vmbr1)                │
│          │                                                          │
│   ┌──────┼──────────┬────────────────┬────────────────┐             │
│   │      │          │                │                │             │
│   ▼      ▼          ▼                ▼                ▼             │
│ ┌──────┐ ┌────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐       │
│ │VM 100│ │VM 101  │ │VM 102    │ │VM 103    │ │VM 104      │       │
│ │MQTT  │ │MQTT    │ │WebSocket │ │WebSocket │ │App/Service │       │
│ │Brkr 1│ │Brkr 2  │ │Server 1  │ │Server 2  │ │Lainnya     │       │
│ │:1883 │ │:1884   │ │:8083     │ │:8083     │ │:8080       │       │
│ │      │ │        │ │          │ │          │ │            │       │
│ │.1.10 │ │.1.11   │ │.1.12     │ │.1.13     │ │.1.14       │       │
│ └──────┘ └────────┘ └──────────┘ └──────────┘ └────────────┘       │
│                                                                     │
│  IP Format: 192.168.1.x (semua VM di jaringan bridge yang sama)     │
└─────────────────────────────────────────────────────────────────────┘
```

## Kenapa Arsitektur Ini Bekerja?

Konsep utamanya sederhana:

1. **Newt hanya perlu 1 instance** — dijalankan di satu VM gateway, membuat tunnel WireGuard ke VPS.
2. **Newt bisa menjangkau semua VM** — selama VM-VM berada di jaringan yang sama (misal `vmbr0`), Newt bisa meneruskan traffic ke IP masing-masing VM.
3. **Setiap service di VM berbeda** di-register sebagai Resource terpisah di Pangolin, dengan target IP internal masing-masing VM.

Ini artinya kamu **tidak perlu install Newt di setiap VM**. Cukup satu Newt di satu VM yang bertindak sebagai gateway tunnel.

---

## Opsi Arsitektur

### Opsi A: Single Newt Gateway (Direkomendasikan)

```
VPS ◄──── WireGuard ────► [VM-Gateway + Newt] ──► VM-100 (MQTT 1)
                                                ──► VM-101 (MQTT 2)
                                                ──► VM-102 (WS 1)
                                                ──► VM-103 (WS 2)
```

- **Kelebihan**: Sederhana, satu titik management, hemat resource
- **Kekurangan**: Single point of failure di VM gateway
- **Cocok untuk**: Kebanyakan use case, homelab, small-medium deployment

### Opsi B: Newt Per-VM (Isolasi Penuh)

```
VPS ◄──── WireGuard ────► [VM-100 + Newt] (MQTT 1)
    ◄──── WireGuard ────► [VM-101 + Newt] (MQTT 2)
    ◄──── WireGuard ────► [VM-102 + Newt] (WS 1)
    ◄──── WireGuard ────► [VM-103 + Newt] (WS 2)
```

- **Kelebihan**: Isolasi penuh, tidak ada single point of failure
- **Kekurangan**: Lebih banyak resource, lebih banyak Site di Pangolin
- **Cocok untuk**: Production, kebutuhan high availability

### Opsi C: Newt di LXC Container di Proxmox Host

```
VPS ◄──── WireGuard ────► [LXC Container + Newt di Proxmox] ──► VM-100
                                                               ──► VM-101
                                                               ──► dst
```

- **Kelebihan**: Lebih ringan (LXC vs VM), langsung di host
- **Kekurangan**: Perlu konfigurasi network forwarding di LXC
- **Cocok untuk**: Setup yang optimal dari sisi resource

---

## Persyaratan

### VPS (Server Publik)

- Ubuntu 20.04+ atau Debian 11+
- RAM minimal 1 GB (2 GB direkomendasikan)
- Storage 20 GB+ SSD
- IP Publik
- Port terbuka: 80, 443, 51820/udp, 21820/udp, 1883, 1884, 8083, 8084

### Proxmox Host

- Proxmox VE 7.x atau 8.x
- Jaringan bridge (vmbr0) yang menghubungkan semua VM
- Minimal 1 VM untuk Newt gateway
- VM-VM target dengan service yang berjalan

### Domain

- Domain terdaftar
- Akses DNS management untuk membuat A record dan wildcard

---

## Langkah 1: Konfigurasi DNS

Misal domain `iotproject.com`, IP VPS `203.0.113.50`:

| Type | Name | Value |
|------|------|-------|
| A | `*` | `203.0.113.50` |
| A | `@` | `203.0.113.50` |

Verifikasi:

```bash
dig +short pangolin.iotproject.com
# Output: 203.0.113.50
```

> **Cloudflare users**: Set proxy status ke **DNS only** (ikon awan abu-abu).

---

## Langkah 2: Install Pangolin di VPS

Gunakan script `install-pangolin.sh` yang sudah disediakan:

```bash
ssh root@203.0.113.50
chmod +x install-pangolin.sh
sudo bash install-pangolin.sh
```

Atau gunakan official installer:

```bash
curl -fsSL https://static.pangolin.net/get-installer.sh | bash
sudo ./installer
```

Setelah install, pastikan `allow_raw_resources: true` di `/opt/pangolin/config/config.yml` dan port MQTT/WS ter-expose di `docker-compose.yml`.

Kemudian buka `https://pangolin.iotproject.com/auth/initial-setup` untuk setup awal (buat admin + organization).

---

## Langkah 3: Siapkan VM Gateway di Proxmox

### 3.1 Buat VM Baru

Di Proxmox web UI:

1. **Create VM** → Debian 12 atau Ubuntu 22.04 (server, minimal)
2. **CPU**: 1 core
3. **RAM**: 512 MB - 1 GB
4. **Disk**: 8-10 GB
5. **Network**: Bridge `vmbr0` (pastikan sama dengan VM lain)
6. **Static IP**: Misal `192.168.1.50`

### 3.2 Install Docker di VM Gateway

```bash
# Update
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Logout & login kembali
exit
# SSH kembali
```

### 3.3 Verifikasi Konektivitas ke VM Lain

```bash
# Pastikan bisa reach semua VM target
ping -c 3 192.168.1.10   # VM MQTT Broker 1
ping -c 3 192.168.1.11   # VM MQTT Broker 2
ping -c 3 192.168.1.12   # VM WebSocket 1
ping -c 3 192.168.1.13   # VM WebSocket 2

# Test port juga
nc -zv 192.168.1.10 1883
# Output: Connection to 192.168.1.10 1883 port [tcp/*] succeeded!
```

---

## Langkah 4: Buat Site di Pangolin Dashboard

1. Login ke `https://pangolin.iotproject.com`
2. **Sites** → **Add Site +**
3. Name: `Proxmox-Gateway`
4. Type: **Newt Tunnel** (default)
5. **SALIN** credentials:
   - `PANGOLIN_ENDPOINT`
   - `NEWT_ID`
   - `NEWT_SECRET`
6. Klik **Create Site**

---

## Langkah 5: Deploy Newt di VM Gateway

Di VM gateway (192.168.1.50):

```bash
mkdir -p ~/newt && cd ~/newt
```

Buat `docker-compose.yml`:

```yaml
services:
  newt:
    image: fosrl/newt:latest
    container_name: newt
    restart: unless-stopped
    environment:
      - PANGOLIN_ENDPOINT=https://pangolin.iotproject.com
      - NEWT_ID=paste_id_dari_dashboard
      - NEWT_SECRET=paste_secret_dari_dashboard
```

Jalankan:

```bash
docker compose up -d
docker compose logs -f newt
```

Verifikasi di Pangolin dashboard → Site harus menunjukkan status **Online**.

---

## Langkah 6: Buat Resources (Mapping ke VM)

Ini bagian kunci — setiap resource mengarah ke **IP internal VM yang berbeda** melalui satu Newt gateway.

### Resource 1: MQTT Broker 1 (VM 100 — 192.168.1.10)

| Field | Value |
|-------|-------|
| Name | `MQTT-Broker-1` |
| Site | `Proxmox-Gateway` |
| Type | Raw TCP/UDP Resource |
| Protocol | TCP |
| Public Port | `1883` |
| Target IP | `192.168.1.10` |
| Target Port | `1883` |

### Resource 2: MQTT Broker 2 (VM 101 — 192.168.1.11)

| Field | Value |
|-------|-------|
| Name | `MQTT-Broker-2` |
| Site | `Proxmox-Gateway` |
| Type | Raw TCP/UDP Resource |
| Protocol | TCP |
| Public Port | `1884` |
| Target IP | `192.168.1.11` |
| Target Port | `1884` |

### Resource 3: WebSocket Server 1 (VM 102 — 192.168.1.12)

**Opsi HTTP (direkomendasikan untuk browser, dengan SSL otomatis):**

| Field | Value |
|-------|-------|
| Name | `WebSocket-1` |
| Site | `Proxmox-Gateway` |
| Type | HTTP Resource |
| Subdomain | `ws` |
| Target IP | `192.168.1.12` |
| Target Port | `8083` |

Akses via: `wss://ws.iotproject.com`

### Resource 4: WebSocket Server 2 (VM 103 — 192.168.1.13)

| Field | Value |
|-------|-------|
| Name | `WebSocket-2` |
| Site | `Proxmox-Gateway` |
| Type | HTTP Resource |
| Subdomain | `ws2` |
| Target IP | `192.168.1.13` |
| Target Port | `8084` |

### Bonus: Service HTTP Lainnya

Kamu bisa tambahkan VM apapun dengan cara yang sama:

| Field | Value |
|-------|-------|
| Name | `Web-App` |
| Type | HTTP Resource |
| Subdomain | `app` |
| Target IP | `192.168.1.14` |
| Target Port | `8080` |

---

## Langkah 7: Testing

### Test MQTT dari Internet

```bash
# Subscribe (terminal 1)
mosquitto_sub -h iotproject.com -p 1883 -t "sensor/temp" -v

# Publish (terminal 2)
mosquitto_pub -h iotproject.com -p 1883 -t "sensor/temp" -m '{"value": 25.5}'
```

### Test WebSocket dari Browser

```javascript
const ws = new WebSocket('wss://ws.iotproject.com');
ws.onopen = () => console.log('Connected to WS via Proxmox tunnel!');
ws.onmessage = (e) => console.log('Data:', e.data);
```

---

## Menambah VM Baru di Kemudian Hari

Salah satu keunggulan utama arsitektur ini:

1. Buat VM baru di Proxmox → set static IP (misal `192.168.1.20`)
2. Install service yang diinginkan
3. Buka Pangolin Dashboard → **Add Resource**
4. Pilih Site `Proxmox-Gateway`
5. Set target ke `192.168.1.20:PORT`
6. **Selesai** — tidak perlu install Newt lagi!

---

## Setup Opsi B: Newt Per-VM (Opsional)

Jika kamu ingin isolasi penuh dimana setiap VM punya tunnel sendiri:

1. **Buat Site baru** di Pangolin untuk setiap VM
2. **Install Docker + Newt** di setiap VM
3. **Resource target** ke `localhost` (bukan IP internal)

Contoh di VM 100:

```yaml
services:
  newt:
    image: fosrl/newt:latest
    container_name: newt
    restart: unless-stopped
    environment:
      - PANGOLIN_ENDPOINT=https://pangolin.iotproject.com
      - NEWT_ID=id_khusus_vm100
      - NEWT_SECRET=secret_khusus_vm100
```

Resource: Site `VM-100-MQTT`, Target `localhost:1883`.

---

## Proxmox Network Tips

### Pastikan vmbr0 bridge benar

Di Proxmox host, cek `/etc/network/interfaces`:

```
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.1/24
    gateway 192.168.1.1
    bridge-ports ens18
    bridge-stp off
    bridge-fd 0
```

### Static IP untuk semua VM

Sangat penting agar resource Pangolin selalu mengarah ke IP yang benar.

Ubuntu/Debian di VM:

```yaml
# /etc/netplan/00-config.yaml
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: false
      addresses:
        - 192.168.1.10/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
sudo netplan apply
```

### Firewall antar-VM

Jika Proxmox firewall aktif, pastikan traffic antar-VM diizinkan, atau disable firewall untuk bridge internal.

---

## Alur Packet Detail

```
[IoT Device]
     │
     │ MQTT CONNECT ke iotproject.com:1883
     ▼
[DNS Resolve] → 203.0.113.50 (VPS)
     │
     ▼
[VPS: Traefik] menerima TCP :1883
     │
     ▼
[VPS: Gerbil] forward via WireGuard
     │
     ▼
[Proxmox VM-Gateway: Newt] menerima dari tunnel
     │ Target: 192.168.1.10:1883
     ▼
[Proxmox vmbr0 Bridge]
     │
     ▼
[VM 100: MQTT Broker] → CONNACK → balik lewat jalur yang sama
     │
     ▼
[MQTT Session aktif, bidirectional melalui tunnel]
```

---

## Maintenance

### Backup Pangolin (VPS)

```bash
cd /opt/pangolin
cp -r config config.backup.$(date +%Y%m%d)
```

### Update Pangolin

```bash
cd /opt/pangolin
docker compose pull && docker compose up -d
```

### Update Newt (VM Gateway)

```bash
cd ~/newt
docker compose pull && docker compose up -d
```

### Backup VM di Proxmox

```bash
# Dari Proxmox host
vzdump 100 --storage local --compress zstd
```

---

## Troubleshooting

| Problem | Solusi |
|---------|--------|
| Dashboard tidak bisa diakses | Cek DNS (`dig`), container status (`docker compose ps`), logs Traefik |
| Site menunjukkan "Offline" | Cek Newt logs, pastikan internet outbound OK, verifikasi credentials |
| MQTT tidak connect | Pastikan `allow_raw_resources: true`, cek port di firewall & docker-compose |
| VM target tidak reachable | Cek bridge network, ping dari VM gateway ke VM target, cek static IP |
| SSL error | Tunggu beberapa menit, cek port 80 terbuka, pastikan DNS sudah propagasi |
| Latency tinggi | Pilih VPS dekat secara geografis, gunakan kernel WireGuard di Newt |

---

## Referensi

- **Pangolin Docs**: [docs.pangolin.net](https://docs.pangolin.net)
- **Raw TCP/UDP Resources**: [docs.pangolin.net/manage/resources/public/raw-resources](https://docs.pangolin.net/manage/resources/public/raw-resources)
- **Pangolin GitHub**: [github.com/fosrl/pangolin](https://github.com/fosrl/pangolin)
- **Proxmox Networking**: [pve.proxmox.com/wiki/Network_Configuration](https://pve.proxmox.com/wiki/Network_Configuration)
- **Pangolin Discord**: [pangolin.net/discord](https://pangolin.net/discord)
