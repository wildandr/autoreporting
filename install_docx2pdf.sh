#!/bin/bash

# Script untuk menginstal docx2pdf dan dependensi yang diperlukan
# Usage: sudo bash install_docx2pdf.sh

set -e

echo "=== Instalasi docx2pdf dan Dependensi ==="

# Periksa jika dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini sebaiknya dijalankan sebagai root. Gunakan sudo."
    read -p "Lanjutkan? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

APP_DIR="/root/autoreporting"

echo -e "\n[1/5] Menginstal dependensi sistem..."
apt-get update
apt-get install -y python3-pip python3-venv

echo -e "\n[2/5] Memeriksa virtual environment..."
if [ -d "$APP_DIR/venv" ]; then
    echo "Virtual environment ditemukan di $APP_DIR/venv"
    source "$APP_DIR/venv/bin/activate"
else
    echo "Virtual environment tidak ditemukan. Membuat yang baru..."
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    python3 -m venv venv
    source venv/bin/activate
fi

echo -e "\n[3/5] Menginstal docx2pdf dan dependensinya..."
pip install docx2pdf streamlit python-docx pandas requests

echo -e "\n[4/5] Memastikan dependensi tambahan untuk PDF conversion..."
apt-get install -y default-jre

# Pada sistem berbasis Debian/Ubuntu, pastikan Java dapat digunakan oleh Python
if [ ! -f /etc/alternatives/java ]; then
    echo "PERINGATAN: Java tidak terinstal dengan benar."
    apt-get install -y default-jre
fi

echo -e "\n[5/5] Verifikasi instalasi..."
python -c "import docx2pdf; print('docx2pdf berhasil diimpor')" || echo "PERINGATAN: docx2pdf tidak dapat diimpor"

echo -e "\n=== Instalasi Selesai ==="
echo "docx2pdf dan dependensinya telah diinstal."
echo "Pastikan untuk menjalankan service ulang jika Anda mengubah file aplikasi:"
echo "sudo systemctl restart daily-report"
echo ""
echo "Catatan: Konversi PDF menggunakan docx2pdf memerlukan Java Runtime Environment."
echo "Jika konversi PDF gagal, pastikan Java terinstal dengan benar:"
echo "sudo apt-get install -y default-jre"
