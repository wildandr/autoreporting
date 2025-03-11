#!/bin/bash

# Script untuk menonaktifkan layanan Flask dan menyelesaikan masalah konflik port
# Usage: sudo bash stop_service.sh

set -e

echo "=== Menghentikan dan Menyelesaikan Masalah Layanan Flask ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

# Step 1: Disable dan stop layanan Flask
echo -e "\n[1/4] Menonaktifkan dan menghentikan layanan daily-report-flask..."
systemctl stop daily-report-flask
systemctl disable daily-report-flask
echo "✅ Layanan daily-report-flask telah dinonaktifkan dan dihentikan."

# Step 2: Identifikasi proses yang menggunakan port 8080
echo -e "\n[2/4] Mengidentifikasi proses yang menggunakan port 8080..."
PORT_PROCESS=$(lsof -i:8080 -t)

if [ -z "$PORT_PROCESS" ]; then
    echo "Tidak ada proses yang menggunakan port 8080."
else
    echo "Proses-proses berikut menggunakan port 8080:"
    lsof -i:8080
    
    echo -e "\n[3/4] Menghentikan proses tersebut..."
    for PID in $PORT_PROCESS; do
        echo "Menghentikan proses dengan PID $PID..."
        kill -9 $PID
    done
    echo "✅ Semua proses yang menggunakan port 8080 telah dihentikan."
fi

# Step 4: Verifikasi bahwa port sudah bebas
echo -e "\n[4/4] Memverifikasi bahwa port 8080 sudah bebas..."
sleep 2
if lsof -i:8080 &>/dev/null; then
    echo "❌ Port 8080 masih digunakan oleh proses lain."
    lsof -i:8080
else
    echo "✅ Port 8080 sekarang bebas dan dapat digunakan."
fi

echo -e "\n=== Informasi Layanan ==="
echo "Untuk mengaktifkan layanan Flask dengan port berbeda di kemudian hari, jalankan:"
echo "sudo systemctl edit daily-report-flask"
echo "Dan tambahkan atau ubah baris ExecStart menjadi:"
echo "ExecStart=/opt/daily_report_app/venv/bin/gunicorn -b 0.0.0.0:8081 -w 4 app:app"
echo "(Ganti 8081 dengan port yang diinginkan)"
echo ""
echo "Kemudian jalankan:"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable daily-report-flask"
echo "sudo systemctl start daily-report-flask"
echo ""
echo "=== Selesai ==="
echo "Semua proses pada port 8080 telah dihentikan dan layanan daily-report-flask telah dinonaktifkan."
