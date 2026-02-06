# Panduan Lengkap: Pangolin VPS Tunneling untuk MQTT & WebSocket

## Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET / CLIENT                        │
│                                                                 │
│   IoT Device ──► mqtt.domain.com:1883  (MQTT Broker 1)         │
│   IoT Device ──► mqtt2.domain.com:1884 (MQTT Broker 2)         │
│   Browser    ──► ws.domain.com:8083    (WebSocket Server 1)     │
│   Browser    ──► ws2.domain.com:8084   (WebSocket Server 2)     │
│   Admin      ──► pangolin.domain.com   (Dashboard UI)           │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                   ┌───────────▼───────────┐
                   │     VPS (Public IP)    │
                   │                       │
                   │  ┌─────────────────┐  │
                   │  │    Pangolin     │  │
                   │  │  (Management +  │  │
                   │  │   Dashboard UI) │  │
                   │  └────────┬────────┘  │
                   │           │           │
                   │  ┌────────▼────────┐  │
                   │  │    Traefik      │  │
                   │  │ (Reverse Proxy  │  │
                   │  │  + SSL + TCP    │  │
                   │  │  Routing)       │  │
                   │  └────────┬────────┘  │
                   │           │           │
                   │  ┌────────▼────────┐  │
                   │  │    Gerbil       │  │
                   │  │  (WireGuard     │  │
                   │  │   Tunnel Mgr)   │  │
                   │  └────────┬────────┘  │
                   │           │           │
                   │     Port 51820/UDP    │
                   │    (WireGuard Tunnel) │
                   └───────────┬───────────┘
                               │
                 ══════════════╪══════════════
                  Encrypted WireGuard Tunnel
                 ══════════════╪══════════════
                               │
                   ┌───────────▼───────────┐
                   │   SERVER LOKAL (NAT)   │
                   │                       │
                   │  ┌─────────────────┐  │
                   │  │   Newt Client   │  │
                   │  │  (WG Tunnel     │  │
                   │  │   Connector)    │  │
                   │  └────────┬────────┘  │
                   │           │           │
                   │   ┌───────┴────────┐  │
                   │   │                │  │
                   │ ┌─▼──┐          ┌──▼┐ │
                   │ │MQTT│          │WS │ │
                   │ │Brkr│          │Srv│ │
                   │ │1+2 │          │1+2│ │
                   │ └────┘          └───┘ │
                   │                       │
                   │ Broker 1: port 1883   │
                   │ Broker 2: port 1884   │
                   │ WS Srv 1: port 8083   │
                   │ WS Srv 2: port 8084   │
                   └───────────────────────┘
```

## Penjelasan Komponen

| Komponen | Fungsi |
|----------|--------|
| **Pangolin** | Server management utama dengan dashboard web UI untuk mengatur sites, resources, users, dan access control |
| **Gerbil** | WireGuard interface manager yang membuat dan mengelola tunnel terenkripsi |
| **Traefik** | Reverse proxy yang menangani routing HTTP/HTTPS dan TCP/UDP, termasuk SSL otomatis via Let's Encrypt |
| **Newt** | Client tunnel ringan yang berjalan di server lokal, membuat koneksi WireGuard outbound ke VPS |

## Alur Data MQTT

```
IoT Device                    VPS                         Server Lokal
    │                          │                              │
    │  MQTT CONNECT            │                              │
    ├─────────────────────────►│                              │
    │  mqtt.domain.com:1883    │                              │
    │                          │  Traefik menerima TCP        │
    │                          │  di port 1883                │
    │                          │                              │
    │                          │  Forward via WireGuard       │
    │                          ├─────────────────────────────►│
    │                          │  tunnel ke Newt              │
    │                          │                              │
    │                          │                 Newt forward │
    │                          │                 ke MQTT      │
    │                          │                 Broker local │
    │                          │                 (localhost    │
    │                          │                  :1883)       │
    │                          │                              │
    │  ◄── MQTT CONNACK ──────┤◄─────────────────────────────┤
    │                          │                              │
    │  PUBLISH/SUBSCRIBE       │                              │
    │  ◄═══════════════════════╪══════════════════════════════╡
    │  (bidirectional)         │                              │
```

---

## Persyaratan

### VPS (Server Publik)

- **OS**: Ubuntu 20.04+ atau Debian 11+ (direkomendasikan)
- **RAM**: Minimal 1 GB (2 GB direkomendasikan)
- **Storage**: 20 GB+ SSD
- **IP Publik**: Wajib
- **Port terbuka**: 80/tcp, 443/tcp, 51820/udp, 21820/udp, 1883/tcp, 1884/tcp, 8083/tcp, 8084/tcp

### Server Lokal

- **Docker** terinstall
- Akses internet outbound (tidak perlu port forwarding)
- MQTT Broker berjalan (contoh: Mosquitto, EMQX, dll.)
- WebSocket Server berjalan

### Domain

- Domain terdaftar dengan akses ke DNS management
- Kemampuan membuat A record dan wildcard record

---

## Langkah 1: Konfigurasi DNS

Sebelum instalasi, konfigurasikan DNS records di provider domain kamu.

Misalnya domain kamu `iotproject.com` dan IP VPS `203.0.113.50`:

| Type | Name | Value | Keterangan |
|------|------|-------|------------|
| A | `*` | `203.0.113.50` | Wildcard — semua subdomain mengarah ke VPS |
| A | `@` | `203.0.113.50` | Root domain (opsional) |

Dengan konfigurasi ini, subdomain berikut akan otomatis resolve:

- `pangolin.iotproject.com` → Dashboard Pangolin
- `mqtt.iotproject.com` → MQTT Broker 1 (via TCP tunnel)
- `mqtt2.iotproject.com` → MQTT Broker 2 (via TCP tunnel)
- `ws.iotproject.com` → WebSocket Server 1
- `ws2.iotproject.com` → WebSocket Server 2

> **Catatan untuk pengguna Cloudflare**: Set proxy status ke **DNS only** (ikon awan abu-abu) agar Let's Encrypt bisa memverifikasi domain.

Tunggu propagasi DNS (5 menit - 48 jam). Verifikasi dengan:

```bash
# Cek dari terminal
dig +short pangolin.iotproject.com
# Harus menampilkan IP VPS kamu
```

---

## Langkah 2: Instalasi Pangolin di VPS

### Opsi A: Menggunakan Script Otomatis (Direkomendasikan)

1. SSH ke VPS:

```bash
ssh root@203.0.113.50
```

2. Download dan jalankan script installer:

```bash
# Download script
wget -O install-pangolin.sh https://YOUR_HOSTED_URL/install-pangolin.sh
# atau copy manual dari file install-pangolin.sh yang disediakan

# Beri permission
chmod +x install-pangolin.sh

# Jalankan
sudo bash install-pangolin.sh
```

3. Ikuti prompt interaktif:
   - Masukkan base domain (`iotproject.com`)
   - Subdomain dashboard (`pangolin`)
   - Email admin
   - Password admin
   - Port MQTT dan WebSocket
   - Opsi SMTP dan CrowdSec

### Opsi B: Menggunakan Pangolin Quick Installer (Official)

```bash
# Download installer official
curl -fsSL https://static.pangolin.net/get-installer.sh | bash

# Jalankan
sudo ./installer
```

Kemudian tambahkan konfigurasi TCP port secara manual (lihat Langkah 4).

### Opsi C: Instalasi Manual

Ikuti langkah-langkah di script `install-pangolin.sh` secara manual, atau lihat dokumentasi resmi di [docs.pangolin.net](https://docs.pangolin.net/self-host/manual/docker-compose).

---

## Langkah 3: Verifikasi Instalasi

Setelah instalasi selesai:

```bash
# Cek status container
cd /opt/pangolin
docker compose ps
```

Output yang diharapkan:

```
NAME        IMAGE                       STATUS
pangolin    fosrl/pangolin:latest       Up (healthy)
gerbil      fosrl/gerbil:latest         Up
traefik     traefik:v3.6                Up
```

Buka browser dan akses:

```
https://pangolin.iotproject.com/auth/initial-setup
```

Pada halaman initial setup:
1. Buat akun admin (email + password)
2. Buat Organization pertama (contoh: "IoT Project")
3. Kamu akan masuk ke dashboard Pangolin

---

## Langkah 4: Aktifkan Raw TCP Resources

Untuk tunneling MQTT (yang menggunakan TCP, bukan HTTP), kamu perlu memastikan fitur `allow_raw_resources` aktif.

### Verifikasi config.yml

```bash
nano /opt/pangolin/config/config.yml
```

Pastikan ada baris:

```yaml
flags:
  allow_raw_resources: true
```

### Pastikan port ter-expose di docker-compose.yml

Verifikasi bagian `ports` di service `gerbil`:

```yaml
gerbil:
  ports:
    - 51820:51820/udp
    - 21820:21820/udp
    - 443:443
    - 80:80
    # MQTT
    - 1883:1883
    - 1884:1884
    # WebSocket
    - 8083:8083
    - 8084:8084
```

### Pastikan Traefik entrypoints dikonfigurasi

Di `config/traefik/traefik_config.yml`, pastikan ada entrypoints untuk setiap port:

```yaml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
  mqtt1:
    address: ":1883"
  mqtt2:
    address: ":1884"
  ws1:
    address: ":8083"
  ws2:
    address: ":8084"
```

Jika ada perubahan, restart:

```bash
cd /opt/pangolin
docker compose down
docker compose up -d
```

---

## Langkah 5: Setup Newt di Server Lokal

Newt adalah client tunnel yang berjalan di server lokal kamu. Ia membuat koneksi WireGuard outbound ke VPS, sehingga tidak perlu port forwarding di router.

### 5.1 Buat Site di Pangolin Dashboard

1. Login ke `https://pangolin.iotproject.com`
2. Navigasi ke **Sites** → **Add Site +**
3. Beri nama (contoh: `MQTT-Server-Local`)
4. Pilih **Newt Tunnel** (default)
5. **PENTING**: Salin credentials yang muncul:
   - `NEWT_ID`
   - `NEWT_SECRET`
6. Klik **"I have copied the config"** → **Create Site**

### 5.2 Install Newt via Docker di Server Lokal

Di server lokal yang menjalankan MQTT Broker:

```bash
# Buat direktori
mkdir -p ~/pangolin-newt
cd ~/pangolin-newt

# Buat docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  newt:
    image: fosrl/newt:latest
    container_name: newt
    restart: unless-stopped
    environment:
      - PANGOLIN_ENDPOINT=https://pangolin.iotproject.com
      - NEWT_ID=GANTI_DENGAN_NEWT_ID_DARI_DASHBOARD
      - NEWT_SECRET=GANTI_DENGAN_NEWT_SECRET_DARI_DASHBOARD
EOF

# Edit dengan credentials yang benar
nano docker-compose.yml

# Jalankan
docker compose up -d

# Cek logs
docker compose logs -f newt
```

### 5.3 Verifikasi Koneksi

- Di dashboard Pangolin, cek **Sites** → site kamu harus menunjukkan status **Online**
- Di logs Newt, kamu harus melihat pesan koneksi sukses dan ping checks

---

## Langkah 6: Buat Resources untuk MQTT & WebSocket

Setelah Site online, buat resources untuk setiap service yang ingin di-tunnel.

### 6.1 MQTT Broker 1 (Raw TCP)

1. Di dashboard → **Resources** → **Add Resource +**
2. **Name**: `MQTT Broker 1`
3. **Site**: Pilih site yang baru dibuat
4. **Resource Type**: **Raw TCP/UDP Resource**
5. **Protocol**: TCP
6. **Public Port**: `1883`
7. **Target**:
   - **IP/Hostname**: `localhost` (atau IP lokal MQTT broker, misal `192.168.1.100`)
   - **Port**: `1883`
8. Klik **Save**

### 6.2 MQTT Broker 2 (Raw TCP)

Ulangi langkah di atas dengan:
- **Name**: `MQTT Broker 2`
- **Public Port**: `1884`
- **Target Port**: `1884` (atau port broker kedua di server lokal)

### 6.3 WebSocket Server 1 (HTTP Resource atau Raw TCP)

Ada 2 pendekatan untuk WebSocket:

**Opsi A — HTTP Resource (dengan SSL/TLS otomatis):**

1. **Resource Type**: **HTTP Resource**
2. **Subdomain**: `ws`
3. **Target**: `localhost:8083`
4. Client mengakses via: `wss://ws.iotproject.com`

**Opsi B — Raw TCP (tanpa SSL, untuk kompatibilitas):**

1. **Resource Type**: **Raw TCP/UDP Resource**
2. **Public Port**: `8083`
3. **Target**: `localhost:8083`
4. Client mengakses via: `ws://VPS_IP:8083`

### 6.4 WebSocket Server 2

Ulangi untuk server kedua dengan port `8084`.

---

## Langkah 7: Testing Koneksi

### Test MQTT

```bash
# Dari komputer manapun (install mosquitto-clients dulu)
# Subscribe
mosquitto_sub -h iotproject.com -p 1883 -t "test/topic" -v

# Di terminal lain, Publish
mosquitto_pub -h iotproject.com -p 1883 -t "test/topic" -m "Hello from tunnel!"
```

### Test WebSocket

Jika menggunakan HTTP Resource dengan SSL:

```javascript
// Browser console atau Node.js
const ws = new WebSocket('wss://ws.iotproject.com');
ws.onopen = () => {
  console.log('Connected!');
  ws.send('Hello via tunnel!');
};
ws.onmessage = (event) => console.log('Received:', event.data);
```

Jika menggunakan Raw TCP:

```javascript
const ws = new WebSocket('ws://203.0.113.50:8083');
// ...
```

---

## Pengelolaan & Maintenance

### Perintah Umum

```bash
# Masuk ke direktori Pangolin
cd /opt/pangolin

# Lihat status
docker compose ps

# Lihat logs realtime
docker compose logs -f

# Logs per container
docker compose logs -f pangolin
docker compose logs -f gerbil
docker compose logs -f traefik

# Restart semua
docker compose restart

# Stop semua
docker compose down

# Update ke versi terbaru
docker compose pull
docker compose up -d
```

### Backup

```bash
# Backup konfigurasi
cp -r /opt/pangolin/config /opt/pangolin/config.backup.$(date +%Y%m%d)

# Backup database
cp /opt/pangolin/config/db/db.sqlite /opt/pangolin/config/db/db.sqlite.backup.$(date +%Y%m%d)
```

### Update Pangolin

```bash
cd /opt/pangolin

# Backup dulu!
cp -r config config.backup.$(date +%Y%m%d)

# Pull versi terbaru
docker compose pull

# Restart dengan versi baru
docker compose up -d

# Verifikasi
docker compose ps
```

---

## Troubleshooting

### Dashboard tidak bisa diakses

1. Cek DNS sudah propagasi: `dig +short pangolin.iotproject.com`
2. Cek container running: `docker compose ps`
3. Cek logs Traefik: `docker compose logs traefik`
4. Pastikan port 80 dan 443 terbuka: `ufw status`

### Site menunjukkan "Offline"

1. Cek Newt running di server lokal: `docker compose logs newt`
2. Pastikan server lokal bisa akses internet outbound
3. Verifikasi NEWT_ID dan NEWT_SECRET benar
4. Cek port 51820/UDP terbuka di VPS

### MQTT tidak bisa connect

1. Pastikan `allow_raw_resources: true` di config.yml
2. Cek port di firewall: `ufw status | grep 1883`
3. Cek port di docker-compose.yml (bagian gerbil ports)
4. Cek entrypoint di traefik_config.yml
5. Test koneksi lokal dulu: `mosquitto_pub -h localhost -p 1883 -t test -m test`
6. Restart setelah perubahan: `docker compose down && docker compose up -d`

### SSL Certificate gagal

1. Pastikan DNS mengarah ke IP VPS (bukan Cloudflare proxy)
2. Cek port 80 terbuka (diperlukan untuk HTTP challenge)
3. Lihat logs: `docker compose logs traefik | grep acme`
4. Tunggu beberapa menit, certificate generation butuh waktu

---

## Keamanan

### Rekomendasi Keamanan

1. **Gunakan SSH key** dan disable password authentication
2. **Disable signup** tanpa invite (sudah default di script)
3. **Aktifkan 2FA** di akun admin Pangolin
4. **Pertimbangkan MQTT over TLS** untuk enkripsi end-to-end
5. **Monitor logs** secara berkala
6. **Update** Pangolin dan Newt secara rutin
7. **Backup** konfigurasi dan database secara berkala

### MQTT Security Tips

Untuk produksi, pertimbangkan:

- Konfigurasi authentication di MQTT Broker (username/password)
- Gunakan ACL (Access Control List) untuk membatasi topic
- Jika memungkinkan, gunakan MQTT over TLS (port 8883) dengan sertifikat
- Batasi akses berdasarkan IP menggunakan Pangolin access rules

---

## Referensi

- **Pangolin Docs**: [docs.pangolin.net](https://docs.pangolin.net)
- **Pangolin GitHub**: [github.com/fosrl/pangolin](https://github.com/fosrl/pangolin)
- **Raw TCP/UDP Resources**: [docs.pangolin.net/manage/resources/public/raw-resources](https://docs.pangolin.net/manage/resources/public/raw-resources)
- **DNS & Networking**: [docs.pangolin.net/self-host/dns-and-networking](https://docs.pangolin.net/self-host/dns-and-networking)
- **Pangolin Discord**: [pangolin.net/discord](https://pangolin.net/discord)
