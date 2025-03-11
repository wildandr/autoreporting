#!/bin/bash

# Script untuk menjalankan aplikasi secara manual dan melihat output langsung
# Usage: bash manual_run.sh

APP_DIR="/root/autoreporting"
echo "=== Menjalankan Aplikasi Daily Report Generator Secara Manual ==="

# Pindah ke direktori aplikasi
cd $APP_DIR || {
    echo "Direktori $APP_DIR tidak ditemukan!"
    exit 1
}

# Memeriksa keberadaan file utama
if [ ! -f "streamlit.py" ]; then
    echo "FATAL: File streamlit.py tidak ditemukan di direktori saat ini!"
    echo "Direktori saat ini: $(pwd)"
    echo "Daftar file:"
    ls -la
    exit 1
fi

# Cek keberadaan template
if [ ! -f "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
    echo "PERINGATAN: Template dokumen tidak ditemukan!"
    echo "Aplikasi mungkin tidak berfungsi dengan baik tanpa template dokumen."
fi

# Periksa dan aktifkan virtual environment
if [ -d "venv" ]; then
    echo "Menggunakan virtual environment yang sudah ada..."
    source venv/bin/activate || {
        echo "Gagal mengaktifkan venv. Membuat yang baru..."
        rm -rf venv
        python3 -m venv venv
        source venv/bin/activate
    }
else
    echo "Virtual environment tidak ditemukan. Membuat yang baru..."
    python3 -m venv venv
    source venv/bin/activate
fi

# Verifikasi dependensi
echo "Memeriksa dependensi..."
pip install --no-cache-dir streamlit python-docx pandas requests

# Cek apakah port 8501 sudah digunakan
PORT=8501
if lsof -i:$PORT > /dev/null 2>&1; then
    echo "PERINGATAN: Port $PORT sudah digunakan oleh proses lain."
    lsof -i:$PORT
    echo "Gunakan port alternatif? (y/n)"
    read -n 1 use_alt_port
    if [[ "$use_alt_port" =~ ^[Yy]$ ]]; then
        PORT=8502
        echo -e "\nMenggunakan port alternatif: $PORT"
    else
        echo -e "\nMencoba menghentikan proses yang menggunakan port $PORT..."
        lsof -ti:$PORT | xargs kill -9 || true
        sleep 1
    fi
fi

echo -e "\n=== Output Aplikasi (CTRL+C untuk berhenti) ==="
echo "URL aplikasi akan tersedia di: http://localhost:$PORT"

PYTHONUNBUFFERED=1 streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT
