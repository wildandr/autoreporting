#!/bin/bash

# Script untuk membersihkan semua proses aplikasi daily report
# Usage: sudo bash cleanup.sh

set -e

echo "=== Membersihkan Semua Proses Aplikasi Daily Report ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

echo -e "\n[1/5] Menghentikan dan menonaktifkan layanan systemd..."
# Menghentikan dan menonaktifkan layanan daily-report
systemctl stop daily-report 2>/dev/null || echo "Layanan daily-report tidak berjalan."
systemctl disable daily-report 2>/dev/null || echo "Layanan daily-report tidak terdaftar."

# Menghentikan dan menonaktifkan layanan daily-report-flask
systemctl stop daily-report-flask 2>/dev/null || echo "Layanan daily-report-flask tidak berjalan."
systemctl disable daily-report-flask 2>/dev/null || echo "Layanan daily-report-flask tidak terdaftar."

echo -e "\n[2/5] Memeriksa dan menghentikan proses streamlit..."
STREAMLIT_PIDS=$(pgrep -f streamlit || echo "")
if [ -n "$STREAMLIT_PIDS" ]; then
    echo "Menghentikan proses streamlit dengan PID: $STREAMLIT_PIDS"
    kill -9 $STREAMLIT_PIDS 2>/dev/null || echo "Tidak dapat menghentikan proses streamlit."
else
    echo "Tidak ada proses streamlit yang berjalan."
fi

echo -e "\n[3/5] Memeriksa dan menghentikan proses gunicorn/flask..."
GUNICORN_PIDS=$(pgrep -f gunicorn || echo "")
if [ -n "$GUNICORN_PIDS" ]; then
    echo "Menghentikan proses gunicorn dengan PID: $GUNICORN_PIDS"
    kill -9 $GUNICORN_PIDS 2>/dev/null || echo "Tidak dapat menghentikan proses gunicorn."
else
    echo "Tidak ada proses gunicorn yang berjalan."
fi

echo -e "\n[4/5] Membersihkan port yang mungkin digunakan..."
# Daftar port yang mungkin digunakan
PORTS=("8080" "8501" "8000" "5000")

for PORT in "${PORTS[@]}"; do
    PORT_PIDS=$(lsof -ti:$PORT 2>/dev/null || echo "")
    if [ -n "$PORT_PIDS" ]; then
        echo "Menutup port $PORT yang digunakan oleh PID: $PORT_PIDS"
        kill -9 $PORT_PIDS 2>/dev/null || echo "Tidak dapat menutup port $PORT."
    else
        echo "Port $PORT tidak digunakan."
    fi
done

echo -e "\n[5/5] Memeriksa jika masih ada proses python terkait..."
PYTHON_PIDS=$(pgrep -f "python.*daily_report" || echo "")
if [ -n "$PYTHON_PIDS" ]; then
    echo "Menghentikan proses python terkait dengan PID: $PYTHON_PIDS"
    kill -9 $PYTHON_PIDS 2>/dev/null || echo "Tidak dapat menghentikan proses python terkait."
else
    echo "Tidak ada proses python terkait yang berjalan."
fi

echo -e "\n=== Verifikasi Hasil ==="
echo "Memeriksa proses yang masih berjalan..."
ps aux | grep -E "streamlit|flask|gunicorn|daily_report" | grep -v grep || echo "Tidak ada proses terkait yang berjalan."

echo "Memeriksa port yang masih digunakan..."
echo "Port 8080:"
lsof -i:8080 2>/dev/null || echo "Port 8080 tidak digunakan."
echo "Port 8501:"
lsof -i:8501 2>/dev/null || echo "Port 8501 tidak digunakan."

echo -e "\n=== Selesai ==="
echo "Semua proses aplikasi daily report telah dihentikan."
echo "Sistem siap untuk instalasi aplikasi baru."
