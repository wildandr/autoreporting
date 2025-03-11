#!/bin/bash

# Script untuk instalasi bersih aplikasi Daily Report setelah pembersihan
# Usage: sudo bash fresh_install.sh [port]

set -e

echo "=== Instalasi Bersih Aplikasi Daily Report ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Tentukan port yang akan digunakan
if [ -z "$1" ]; then
    PORT=8501  # Port default untuk Streamlit
else
    PORT=$1
fi

APP_DIR="/opt/daily_report_app"
SERVICE_NAME="daily-report"
TEMPLATE_FILE="Weekly Daily Report Wildan Dzaky Ramadhani.docx"

echo "Port yang akan digunakan: $PORT"
echo "Direktori aplikasi: $APP_DIR"

# Jalankan pembersihan terlebih dahulu
echo -e "\n[1/8] Membersihkan instalasi sebelumnya..."
bash cleanup.sh

echo -e "\n[2/8] Memeriksa port $PORT..."
if lsof -i:$PORT &>/dev/null; then
    echo "PERINGATAN: Port $PORT masih digunakan. Mencoba menghentikan proses..."
    lsof -ti:$PORT | xargs kill -9 || true
    sleep 2
    if lsof -i:$PORT &>/dev/null; then
        echo "ERROR: Port $PORT masih digunakan dan tidak dapat dibebaskan. Silakan pilih port lain."
        exit 1
    fi
fi

echo -e "\n[3/8] Update sistem dan instal dependencies..."
apt update
apt install -y python3 python3-pip python3-venv libreoffice

echo -e "\n[4/8] Membuat direktori aplikasi..."
mkdir -p $APP_DIR

# Salin file aplikasi
cp streamlit.py "$APP_DIR/"

# Periksa dan salin template dokumen
if [ -f "$TEMPLATE_FILE" ]; then
    cp "$TEMPLATE_FILE" "$APP_DIR/"
    echo "Template dokumen berhasil disalin."
else
    echo "PERINGATAN: Template dokumen '$TEMPLATE_FILE' tidak ditemukan."
    echo "Pastikan untuk menyalin template ke direktori $APP_DIR sebelum menjalankan aplikasi."
fi

echo -e "\n[5/8] Membuat virtual environment..."
cd $APP_DIR
python3 -m venv venv
source venv/bin/activate
pip install streamlit python-docx pandas requests
deactivate

echo -e "\n[6/8] Membuat file service systemd..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOL
[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT --server.headless=true --server.enableCORS=false --server.enableXsrfProtection=false
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOL

echo -e "\n[7/8] Mengaktifkan dan memulai service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

# Buka port di firewall jika menggunakan UFW
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo -e "\nMembuka port $PORT di firewall UFW..."
    ufw allow $PORT/tcp
fi

echo -e "\n[8/8] Memeriksa status service..."
sleep 3
systemctl status $SERVICE_NAME --no-pager

# Ambil alamat IP server
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "\n=== Instalasi Selesai! ==="
echo "Aplikasi Daily Report Generator telah diinstal dan dijalankan sebagai service."
echo -e "\nAnda dapat mengakses aplikasi di browser dengan alamat:"
echo "http://$IP_ADDRESS:$PORT"
echo -e "\nUntuk melihat status service:"
echo "sudo systemctl status $SERVICE_NAME"
echo -e "\nUntuk melihat log service:"
echo "sudo journalctl -u $SERVICE_NAME -f"
echo -e "\nInstalasi selesai!"
