#!/bin/bash

# Script untuk memverifikasi status port dan proses
# Usage: bash verify_ports.sh

echo "=== Verifikasi Status Port dan Proses ==="

# Daftar port yang biasa digunakan
PORTS=("8080" "8501" "8000" "5000")

echo -e "\n[1] Status port yang umum digunakan:"
for PORT in "${PORTS[@]}"; do
    echo -n "Port $PORT: "
    if lsof -i:$PORT &>/dev/null; then
        echo "DIGUNAKAN"
        lsof -i:$PORT
    else
        echo "BEBAS"
    fi
done

echo -e "\n[2] Proses-proses terkait yang mungkin masih berjalan:"
ps aux | grep -E "streamlit|flask|gunicorn|daily_report" | grep -v grep || echo "Tidak ada proses terkait yang berjalan."

echo -e "\n[3] Status layanan systemd:"
systemctl list-units --type=service --all | grep -E 'daily|report|flask|streamlit' || echo "Tidak ada layanan terkait."

echo -e "\n[4] Port yang sedang mendengarkan koneksi:"
netstat -tulpn 2>/dev/null | grep LISTEN || echo "Tidak dapat mengambil informasi port yang mendengarkan."

echo -e "\n=== Selesai ==="
echo "Jika semua port terlihat BEBAS dan tidak ada proses terkait yang berjalan, maka sistem siap untuk instalasi baru."
