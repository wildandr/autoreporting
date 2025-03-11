#!/bin/bash

# Script untuk menjalankan aplikasi dari terminal
# Usage: bash run_terminal.sh [port]

set -e

echo "=== Menjalankan Daily Report Generator dari Terminal ==="

# Tentukan port yang akan digunakan
if [ -z "$1" ]; then
    PORT=8501  # Port default untuk Streamlit
else
    PORT=$1
fi

# Periksa apakah port tersedia
if lsof -i:$PORT &>/dev/null; then
    echo "Port $PORT sedang digunakan. Mencoba menghentikan proses..."
    lsof -ti:$PORT | xargs kill -9 || true
    sleep 2
    if lsof -i:$PORT &>/dev/null; then
        echo "Port $PORT masih digunakan. Coba gunakan port lain dengan: bash run_terminal.sh <port_number>"
        exit 1
    fi
fi

# Cek apakah file streamlit.py ada di direktori saat ini
if [ ! -f "streamlit.py" ]; then
    echo "Error: File streamlit.py tidak ditemukan di direktori saat ini"
    exit 1
fi

# Cek apakah template dokumen ada
if [ ! -f "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
    echo "PERINGATAN: File template 'Weekly Daily Report Wildan Dzaky Ramadhani.docx' tidak ditemukan"
    echo "Aplikasi mungkin tidak berfungsi dengan baik tanpa template dokumen"
fi

# Cek apakah venv sudah ada, jika belum, buat baru
if [ ! -d "venv" ]; then
    echo "Virtual environment tidak ditemukan. Membuat yang baru..."
    python3 -m venv venv
    source venv/bin/activate
    pip install streamlit python-docx pandas requests
    deactivate
    echo "Virtual environment berhasil dibuat"
else
    echo "Menggunakan virtual environment yang sudah ada"
fi

# Aktifkan virtual environment dan jalankan aplikasi
echo "Menjalankan aplikasi pada port $PORT..."
echo "Untuk menghentikan aplikasi, tekan Ctrl+C"
echo "==========================================="

# Ambil alamat IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Aplikasi akan tersedia di: http://$IP_ADDRESS:$PORT"

# Jalankan aplikasi
source venv/bin/activate
streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT --server.headless=true
