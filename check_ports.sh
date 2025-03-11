#!/bin/bash

# Script untuk memeriksa status port dan layanan
# Usage: sudo bash check_ports.sh [port]

echo "=== Pemeriksaan Status Port dan Layanan ==="

# Check if specific port was provided
if [ -z "$1" ]; then
    PORT=8080
else
    PORT=$1
fi

echo -e "\n[1] Memeriksa status layanan daily-report-flask..."
systemctl status daily-report-flask --no-pager || echo "Layanan daily-report-flask tidak aktif."

echo -e "\n[2] Memeriksa proses yang menggunakan port $PORT..."
if lsof -i:$PORT > /dev/null 2>&1; then
    echo "Proses yang menggunakan port $PORT:"
    lsof -i:$PORT
else
    echo "Tidak ada proses yang menggunakan port $PORT."
fi

echo -e "\n[3] Daftar semua port yang mendengarkan..."
netstat -tulpn | grep LISTEN

echo -e "\n[4] Status firewall..."
if command -v ufw &>/dev/null; then
    ufw status
else
    echo "UFW firewall tidak diinstal atau tidak diaktifkan."
fi

echo -e "\n[5] Status layanan systemd yang berjalan..."
systemctl list-units --type=service --state=running | grep -E 'daily|report|flask|streamlit'

echo -e "\n=== Selesai ==="
