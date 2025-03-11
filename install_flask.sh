#!/bin/bash

# Script instalasi aplikasi Daily Report Generator (versi Flask)
# Usage: bash install_flask.sh [port]

set -e

echo "=== Daily Report Generator Installer (Flask Version) ==="

# Periksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Gunakan port kustom jika diberikan, jika tidak gunakan port 8080
if [ -z "$1" ]; then
    PORT=8080
else
    PORT=$1
fi

APP_DIR="/opt/daily_report_app"
SERVICE_NAME="daily-report-flask"

echo "Port yang digunakan: $PORT"
echo "Direktori aplikasi: $APP_DIR"

echo -e "\n[1/7] Update sistem dan install dependencies..."
apt update
apt install -y python3 python3-pip python3-venv libreoffice

echo -e "\n[2/7] Membuat direktori aplikasi..."
mkdir -p $APP_DIR
mkdir -p $APP_DIR/templates

# Salin file aplikasi
cp app.py $APP_DIR/
cp -r templates/* $APP_DIR/templates/

# Periksa template docx
if [ -f "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
    cp "Weekly Daily Report Wildan Dzaky Ramadhani.docx" $APP_DIR/
    echo "Template dokumen berhasil disalin."
else
    echo "PERINGATAN: Template dokumen 'Weekly Daily Report Wildan Dzaky Ramadhani.docx' tidak ditemukan."
    echo "Pastikan untuk menyalin template ke direktori $APP_DIR sebelum menjalankan aplikasi."
fi

echo -e "\n[3/7] Membuat virtual environment..."
python3 -m venv $APP_DIR/venv

echo -e "\n[4/7] Menginstall library yang diperlukan..."
$APP_DIR/venv/bin/pip install flask python-docx pandas requests gunicorn

echo -e "\n[5/7] Membuat file konfigurasi supervisor..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOL
[Unit]
Description=Daily Report Generator Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn -b 0.0.0.0:$PORT -w 4 app:app
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOL

echo -e "\n[6/7] Mengaktifkan dan memulai service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Buka port di firewall jika menggunakan UFW
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo -e "\nMembuka port $PORT di firewall UFW..."
    ufw allow $PORT/tcp
fi

echo -e "\n[7/7] Cek status service..."
sleep 3
systemctl status $SERVICE_NAME --no-pager

# Ambil alamat IP server
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "\n=== Instalasi Selesai! ==="
echo "Daily Report Generator (Flask) telah diinstal dan dijalankan sebagai service."
echo -e "\nAnda dapat mengakses aplikasi di browser dengan alamat:"
echo "http://$IP_ADDRESS:$PORT"
echo -e "\nUntuk melihat status service:"
echo "sudo systemctl status $SERVICE_NAME"
echo -e "\nUntuk melihat log service:"
echo "sudo journalctl -u $SERVICE_NAME -f"
echo -e "\nInstalasi selesai!"
