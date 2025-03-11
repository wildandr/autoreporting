#!/bin/bash

# Script untuk menyelesaikan konfigurasi server dan memastikan semua bekerja dengan baik
# Usage: sudo bash finalize_setup.sh

set -e

echo "=== Finalisasi Konfigurasi Server Daily Report Generator ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Lokasi direktori aplikasi
APP_DIR="/root/autoreporting"

echo -e "\n[1/5] Memastikan Nginx diatur untuk autostart..."
systemctl enable nginx
systemctl is-enabled nginx || echo "PERINGATAN: Nginx tidak diatur untuk autostart!"

echo -e "\n[2/5] Memastikan layanan aplikasi diatur untuk autostart..."
# Periksa apakah service file sudah ada
SERVICE_FILE="/etc/systemd/system/daily-report.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Membuat service file untuk aplikasi..."
    cat > $SERVICE_FILE << EOL
[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/streamlit run streamlit.py --server.address=0.0.0.0 --server.port=8501
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOL
    systemctl daemon-reload
fi

# Aktifkan service
systemctl enable daily-report
systemctl is-enabled daily-report || echo "PERINGATAN: Service daily-report tidak diatur untuk autostart!"

echo -e "\n[3/5] Memastikan konfigurasi Nginx untuk reverse proxy..."
NGINX_CONF_FILE="/etc/nginx/sites-available/streamlit"
if [ ! -f "$NGINX_CONF_FILE" ]; then
    echo "Membuat konfigurasi Nginx..."
    cat > $NGINX_CONF_FILE << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8501;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }
}
EOL
    # Aktifkan konfigurasi
    ln -sf $NGINX_CONF_FILE /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
fi

echo -e "\n[4/5] Konfigurasi firewall (UFW)..."
# Cek status UFW
if command -v ufw &>/dev/null; then
    if ! ufw status | grep -q "Status: active"; then
        echo "UFW tidak aktif, mengaktifkan..."
        ufw --force enable
    fi

    # Buka port untuk HTTP (Nginx) dan SSH
    echo "Memastikan port 80 (HTTP) terbuka..."
    ufw allow 80/tcp
    echo "Memastikan port 22 (SSH) terbuka..."
    ufw allow 22/tcp
    
    echo "Status firewall UFW:"
    ufw status
else
    echo "UFW tidak terinstal. Gunakan firewall cloud provider untuk keamanan."
fi

echo -e "\n[5/5] Menyimpan script untuk start/stop/restart aplikasi..."
# Buat script untuk mengelola aplikasi
cat > $APP_DIR/manage_app.sh << EOL
#!/bin/bash
# Script untuk mengelola aplikasi Daily Report Generator
# Usage: sudo bash manage_app.sh [start|stop|restart|status]

ACTION=\$1

case \$ACTION in
    start)
        echo "Memulai aplikasi Daily Report Generator..."
        systemctl start daily-report
        systemctl status daily-report --no-pager
        ;;
    stop)
        echo "Menghentikan aplikasi Daily Report Generator..."
        systemctl stop daily-report
        systemctl status daily-report --no-pager
        ;;
    restart)
        echo "Me-restart aplikasi Daily Report Generator..."
        systemctl restart daily-report
        systemctl status daily-report --no-pager
        ;;
    status)
        echo "Status aplikasi Daily Report Generator:"
        systemctl status daily-report --no-pager
        ;;
    *)
        echo "Penggunaan: bash manage_app.sh [start|stop|restart|status]"
        exit 1
        ;;
esac
EOL

chmod +x $APP_DIR/manage_app.sh

# Restart layanan untuk memastikan konfigurasi terbaru diterapkan
systemctl restart daily-report
systemctl restart nginx

# Ambil alamat IP server
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "\n=== Konfigurasi Selesai! ==="
echo "Aplikasi Daily Report Generator telah diatur untuk berjalan secara otomatis saat server dinyalakan."
echo -e "\nAnda dapat mengakses aplikasi di browser dengan alamat:"
echo "http://$IP_ADDRESS"
echo -e "\nPenggunaan aplikasi:"
echo "- Untuk memulai aplikasi: sudo bash $APP_DIR/manage_app.sh start"
echo "- Untuk menghentikan aplikasi: sudo bash $APP_DIR/manage_app.sh stop"
echo "- Untuk me-restart aplikasi: sudo bash $APP_DIR/manage_app.sh restart"
echo "- Untuk melihat status aplikasi: sudo bash $APP_DIR/manage_app.sh status"
echo -e "\nArsitektur deployment:"
echo "Browser → Port 80 (Nginx) → Port 8501 (Aplikasi Streamlit)"
echo -e "\nKonfigurasi ini aman karena port 8501 tidak dibuka ke internet,"
echo "semua akses melalui Nginx (port 80) yang bertindak sebagai reverse proxy."
