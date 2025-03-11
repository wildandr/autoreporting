#!/bin/bash

# Script untuk menjalankan aplikasi Streamlit dengan output debug
# Usage: bash debug_run.sh [port]

echo "=== Debug Run: Daily Report Generator ==="

# Tentukan port
if [ -z "$1" ]; then
    PORT=8501
else
    PORT=$1
fi

# Kill proses yang mungkin menggunakan port tersebut
echo "Memeriksa apakah port $PORT sudah digunakan..."
if lsof -i:$PORT &>/dev/null; then
    echo "Port $PORT sedang digunakan. Mencoba menghentikan proses..."
    lsof -ti:$PORT | xargs kill -9 || true
    sleep 2
fi

# Periksa lagi untuk memastikan port sudah bebas
if lsof -i:$PORT &>/dev/null; then
    echo "PERINGATAN: Port $PORT masih digunakan setelah mencoba menghentikan proses."
    echo "Proses yang menggunakan port $PORT:"
    lsof -i:$PORT
    echo "Coba gunakan port lain dengan: bash debug_run.sh <port_lain>"
    exit 1
fi

# Cek apakah file aplikasi ada
if [ ! -f "streamlit.py" ]; then
    echo "ERROR: File streamlit.py tidak ditemukan di direktori saat ini."
    echo "Direktori saat ini: $(pwd)"
    echo "Daftar file: $(ls)"
    exit 1
fi

# Cek apakah template dokumen ada
if [ ! -f "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
    echo "PERINGATAN: Template 'Weekly Daily Report Wildan Dzaky Ramadhani.docx' tidak ditemukan."
    echo "Aplikasi mungkin tidak berfungsi dengan baik tanpa template."
fi

# Buat virtual environment jika belum ada
echo "Memeriksa virtual environment..."
if [ ! -d "venv" ]; then
    echo "Membuat virtual environment baru..."
    python3 -m venv venv
    source venv/bin/activate
    echo "Menginstal dependensi..."
    pip install streamlit python-docx pandas requests
else
    source venv/bin/activate
fi

# Cek versi dependensi
echo "Versi library yang terinstal:"
pip list | grep -E "streamlit|python-docx|pandas|requests"

# Tampilkan IP dan informasi lainnya
echo "=== Informasi Jaringan ==="
echo "Alamat IP: $(hostname -I | awk '{print $1}')"
echo "Port: $PORT"
echo "URL aplikasi akan tersedia di: http://$(hostname -I | awk '{print $1}'):$PORT"

# Periksa status firewall
if command -v ufw &>/dev/null; then
    echo "=== Status Firewall (UFW) ==="
    ufw status | grep $PORT || echo "Port $PORT belum dibuka di UFW."
fi

# Periksa status nginx jika terinstal
if command -v nginx &>/dev/null; then
    echo "=== Status Nginx ==="
    systemctl status nginx --no-pager | head -n 10
    
    echo "=== Konfigurasi Nginx untuk port $PORT ==="
    grep -r "proxy_pass.*$PORT" /etc/nginx/ || echo "Tidak ditemukan konfigurasi proxy untuk port $PORT di Nginx."
fi

echo "=== Menjalankan Aplikasi dengan Debug (CTRL+C untuk berhenti) ==="
echo "Jalankan 'curl http://localhost:$PORT' di terminal lain untuk menguji koneksi lokal"

# Jalankan dengan output debug
PYTHONUNBUFFERED=1 streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT --server.enableCORS=false --server.enableXsrfProtection=false --logger.level=debug
