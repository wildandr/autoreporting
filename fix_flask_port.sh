#!/bin/bash

# Script untuk memperbaiki konflik port untuk layanan Flask
# Usage: sudo bash fix_flask_port.sh [port_baru]

set -e

echo "=== Memperbaiki Konfigurasi Port Layanan Flask ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Tentukan port baru yang akan digunakan
if [ -z "$1" ]; then
    NEW_PORT=8081
else
    NEW_PORT=$1
fi

SERVICE_FILE="/etc/systemd/system/daily-report-flask.service"

# Pastikan layanan dihentikan terlebih dahulu
echo -e "\n[1/5] Menghentikan layanan daily-report-flask..."
systemctl stop daily-report-flask 2>/dev/null || true

# Periksa apakah port yang baru sudah digunakan
echo -e "\n[2/5] Memeriksa apakah port $NEW_PORT tersedia..."
if lsof -i:$NEW_PORT &>/dev/null; then
    echo "❌ Port $NEW_PORT sudah digunakan oleh proses lain."
    lsof -i:$NEW_PORT
    echo "Silakan pilih port yang berbeda."
    exit 1
else
    echo "✅ Port $NEW_PORT tersedia dan dapat digunakan."
fi

# Periksa apakah file service ada
echo -e "\n[3/5] Memeriksa file service..."
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ File service $SERVICE_FILE tidak ditemukan."
    echo "Pastikan file service tersebut ada."
    exit 1
fi

# Perbarui file service dengan port baru
echo -e "\n[4/5] Memperbarui file service dengan port $NEW_PORT..."
sed -i "s/-b 0.0.0.0:[0-9]\+/-b 0.0.0.0:$NEW_PORT/g" "$SERVICE_FILE"
echo "✅ File service telah diperbarui dengan port $NEW_PORT."

# Reload daemon dan mulai layanan
echo -e "\n[5/5] Mengaktifkan dan memulai layanan..."
systemctl daemon-reload
systemctl enable daily-report-flask
systemctl start daily-report-flask

# Verifikasi status
echo -e "\nMemeriksa status layanan..."
systemctl status daily-report-flask --no-pager
sleep 2

# Periksa apakah port sudah digunakan oleh layanan flask
if lsof -i:$NEW_PORT | grep -q gunicorn; then
    echo "✅ Layanan Flask berhasil berjalan pada port $NEW_PORT."
else
    echo "❌ Ada masalah dengan layanan Flask. Silakan periksa log:"
    journalctl -u daily-report-flask -n 20 --no-pager
fi

# Buka port di firewall jika diperlukan
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo -e "\nMembuka port $NEW_PORT di firewall..."
    ufw allow $NEW_PORT/tcp
fi

echo -e "\n=== Selesai ==="
echo "Layanan daily-report-flask sekarang dikonfigurasi untuk menggunakan port $NEW_PORT."
echo "Anda dapat mengakses aplikasi di:"
echo "http://$(hostname -I | awk '{print $1}'):$NEW_PORT"
