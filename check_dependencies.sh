#!/bin/bash

# Script untuk memeriksa dan menginstal dependensi yang dibutuhkan
# Usage: bash check_dependencies.sh

echo "=== Memeriksa Dependensi untuk Daily Report Generator ==="

# Fungsi untuk memeriksa paket terinstal
check_package() {
    if ! dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -q "ok installed"; then
        echo "$1 belum terinstal. Menginstal $1..."
        sudo apt-get install -y $1
    else
        echo "✓ $1 sudah terinstal"
    fi
}

# Cek dan update repository jika diperlukan
echo -e "\n[1/4] Memeriksa repository..."
sudo apt-get update

# Cek paket yang dibutuhkan
echo -e "\n[2/4] Memeriksa paket yang dibutuhkan..."
check_package python3
check_package python3-pip
check_package python3-venv
check_package libreoffice

# Cek Python dan pip
echo -e "\n[3/4] Memeriksa versi Python dan pip..."
python3 --version || echo "Python3 tidak ditemukan"
pip3 --version || echo "Pip3 tidak ditemukan"

# Cek LibreOffice untuk konversi PDF
echo -e "\n[4/4] Memeriksa LibreOffice untuk konversi PDF..."
libreoffice --version || echo "LibreOffice tidak ditemukan"

echo -e "\n=== Semua dependensi tersedia ==="
echo "Anda siap menjalankan aplikasi Daily Report Generator"
echo "Jalankan: bash run_terminal.sh"
