#!/bin/bash

# Script untuk memperbaiki masalah service daily-report
# Usage: sudo bash fix_service.sh

set -e

echo "=== Perbaikan Service Daily Report Generator ==="

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

APP_DIR="/root/autoreporting"
SERVICE_FILE="/etc/systemd/system/daily-report.service"

echo -e "\n[1/6] Memeriksa log service untuk menemukan masalah..."
journalctl -u daily-report -n 50 --no-pager > service_error.log
cat service_error.log | grep -i error > errors_only.log

echo -e "\nLog error telah disimpan ke service_error.log dan errors_only.log"
echo -e "Berikut beberapa baris terakhir dari log error:"
tail -n 10 errors_only.log 2>/dev/null || echo "Tidak ada error spesifik yang ditemukan"

echo -e "\n[2/6] Memeriksa environment dan dependensi..."
cd $APP_DIR

# Aktivasi virtual environment untuk pemeriksaan
source venv/bin/activate 2>/dev/null || {
    echo "Virtual environment tidak ditemukan atau rusak. Membuat yang baru..."
    rm -rf venv
    python3 -m venv venv
    source venv/bin/activate
}

# Periksa dependensi
echo "Memeriksa instalasi dependensi..."
pip install streamlit python-docx pandas requests

echo -e "\n[3/6] Memeriksa file aplikasi..."
if [ ! -f "$APP_DIR/streamlit.py" ]; then
    echo "FATAL: File aplikasi streamlit.py tidak ditemukan di $APP_DIR!"
    exit 1
fi

if [ ! -f "$APP_DIR/Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
    echo "PERINGATAN: Template dokumen tidak ditemukan. Mengembalikan dari backup..."
    # Cek jika ada backup terbaru
    LATEST_BACKUP=$(ls -t /root/daily_report_backup_*.tar.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        TEMP_DIR=$(mktemp -d)
        tar -xzf $LATEST_BACKUP -C $TEMP_DIR
        if [ -f "$TEMP_DIR/app/Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
            cp "$TEMP_DIR/app/Weekly Daily Report Wildan Dzaky Ramadhani.docx" $APP_DIR/
            echo "Template dokumen berhasil dipulihkan dari backup."
        fi
        rm -rf $TEMP_DIR
    else
        echo "Tidak ada backup yang ditemukan. Pastikan untuk menyediakan file template."
    fi
fi

echo -e "\n[4/6] Memperbaiki konfigurasi service..."
cat > $SERVICE_FILE << EOL
[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/streamlit run $APP_DIR/streamlit.py --server.address=0.0.0.0 --server.port=8501
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOL

echo -e "\n[5/6] Menguji aplikasi secara manual..."
echo "Mencoba menjalankan aplikasi secara manual untuk memeriksa error..."

cd $APP_DIR
source venv/bin/activate
# Simpan output ke file log
echo "$(date): Uji manual aplikasi" > test_output.log
timeout 5s streamlit run streamlit.py --server.address=0.0.0.0 --server.port=8501 >> test_output.log 2>&1 || true

# Periksa log untuk kesalahan
if grep -i error test_output.log > /dev/null; then
    echo "PERINGATAN: Ditemukan error saat uji manual. Detail di test_output.log"
    echo "Beberapa baris error:"
    grep -i error test_output.log | head -5
else
    echo "Uji manual tidak menunjukkan error yang jelas. Lihat test_output.log untuk detail."
fi

echo -e "\n[6/6] Me-restart service..."
systemctl daemon-reload
systemctl restart daily-report
sleep 2

echo -e "\nMemeriksa status service setelah perbaikan..."
systemctl status daily-report --no-pager

echo -e "\n=== Saran Tambahan ==="
echo "1. Jika service masih gagal, coba jalankan aplikasi secara manual:"
echo "   cd $APP_DIR && source venv/bin/activate && streamlit run streamlit.py"
echo "2. Periksa file log lengkap: journalctl -u daily-report -f"
echo "3. Periksa apakah ada proses yang sudah menggunakan port 8501:"
echo "   lsof -i:8501"
echo "4. Jika port sudah digunakan, ubah port di service file menjadi port lain"
echo "   dan restart service: systemctl daemon-reload && systemctl restart daily-report"
echo "5. Untuk menggunakan port 80 langsung (tidak perlu nginx), update service file dengan port 80"
echo "   dan pastikan tidak ada layanan lain yang menggunakan port 80 (seperti nginx)"
