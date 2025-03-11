#!/bin/bash

# Script untuk memperbaiki konfigurasi Nginx
# Usage: sudo bash nginx_fix.sh [port]

set -e

echo "=== Perbaikan Konfigurasi Nginx untuk Daily Report Generator ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Tentukan port aplikasi
if [ -z "$1" ]; then
    APP_PORT=8501
else
    APP_PORT=$1
fi

echo "Menggunakan port aplikasi: $APP_PORT"

# Periksa status Nginx
echo -e "\n[1/5] Memeriksa status Nginx..."
if ! systemctl is-active --quiet nginx; then
    echo "Nginx tidak aktif. Mengaktifkan Nginx..."
    systemctl start nginx
fi

# Periksa konfigurasi Nginx yang ada
echo -e "\n[2/5] Memeriksa konfigurasi Nginx..."
NGINX_CONF="/etc/nginx/sites-available/streamlit"
if [ -f "$NGINX_CONF" ]; then
    echo "Konfigurasi Nginx ditemukan. Membuat backup..."
    cp "$NGINX_CONF" "$NGINX_CONF.bak.$(date +%Y%m%d%H%M%S)"
else
    echo "Konfigurasi Nginx tidak ditemukan. Membuat baru..."
fi

# Buat konfigurasi Nginx baru dengan timeout yang lebih panjang
echo -e "\n[3/5] Menulis konfigurasi Nginx baru..."
cat > "$NGINX_CONF" << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_buffering off;
    }

    # Tambahkan caching untuk static assets
    location /static {
        proxy_pass http://localhost:$APP_PORT/static;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_cache_valid 200 1h;
        expires 1h;
        add_header Cache-Control "public, max-age=3600";
    }

    # Tambahkan health check endpoint
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # Tingkatkan batas ukuran upload jika diperlukan
    client_max_body_size 10M;
}
EOL

# Aktifkan konfigurasi
echo -e "\n[4/5] Mengaktifkan konfigurasi..."
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
# Hapus default config jika ada
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm -f /etc/nginx/sites-enabled/default
fi

# Validasi dan restart Nginx
echo -e "\n[5/5] Memvalidasi dan me-restart Nginx..."
nginx -t && systemctl restart nginx

# Periksa status Nginx setelah restart
if systemctl is-active --quiet nginx; then
    echo -e "\n✅ Nginx berhasil dikonfigurasi ulang dan berjalan."
    
    # Test koneksi melalui nginx
    echo "Menguji akses melalui Nginx..."
    if curl -s --head http://localhost/health | grep -q "200 OK"; then
        echo "✅ Health check berhasil."
    else
        echo "❌ Health check gagal."
    fi
else
    echo -e "\n❌ Nginx gagal dimulai ulang. Periksa log: journalctl -u nginx"
fi

echo -e "\n=== Konfigurasi Nginx Selesai ==="
echo "Aplikasi sekarang dapat diakses melalui: http://$(hostname -I | awk '{print $1}')"
echo "Port aplikasi internal: $APP_PORT"
echo "Untuk melihat log Nginx: tail -f /var/log/nginx/error.log"
