#!/bin/bash

# Script untuk mengkonfigurasi Nginx sebagai reverse proxy untuk aplikasi Streamlit
# Usage: sudo bash setup_nginx.sh [port]

set -e

# Periksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Tentukan port yang akan digunakan
if [ -z "$1" ]; then
    PORT=8501  # Port default Streamlit
else
    PORT=$1
fi

echo "=== Konfigurasi Nginx untuk Streamlit (port $PORT) ==="

# Pastikan Nginx terinstal
if ! command -v nginx &>/dev/null; then
    echo "Nginx tidak terinstal. Menginstal Nginx..."
    apt update
    apt install -y nginx
fi

# Periksa status Nginx
echo "Memeriksa status Nginx..."
systemctl status nginx --no-pager || (echo "Memulai Nginx..." && systemctl start nginx)

# Buat konfigurasi Nginx untuk aplikasi
echo "Membuat konfigurasi Nginx..."
cat > /etc/nginx/sites-available/streamlit << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
        proxy_read_timeout 300;
    }
}
EOL

# Aktifkan konfigurasi
echo "Mengaktifkan konfigurasi..."
ln -sf /etc/nginx/sites-available/streamlit /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Validasi konfigurasi
echo "Memvalidasi konfigurasi Nginx..."
nginx -t

# Restart Nginx
echo "Me-restart Nginx..."
systemctl restart nginx

# Buka port di firewall
echo "Mengkonfigurasi firewall..."
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    # Buka port 80 (HTTP) untuk akses web
    ufw allow 80/tcp
    
    # Pastikan port aplikasi juga terbuka untuk komunikasi lokal
    ufw allow from 127.0.0.1 to any port $PORT
else
    echo "UFW tidak aktif atau tidak terinstal. Pastikan firewall dikonfigurasi dengan benar."
fi

# Ambil alamat IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo "=== Konfigurasi Selesai ==="
echo "Nginx telah dikonfigurasi sebagai reverse proxy untuk Streamlit"
echo "Aplikasi akan tersedia di: http://$IP_ADDRESS"
echo ""
echo "Untuk menjalankan aplikasi, gunakan:"
echo "bash debug_run.sh $PORT"
echo ""
echo "Pastikan aplikasi berjalan pada port $PORT untuk dapat diakses melalui Nginx"
