#!/bin/bash

# Script untuk menguji konektivitas ke aplikasi
# Usage: bash test_connectivity.sh [port]

# Tentukan port yang akan diuji
if [ -z "$1" ]; then
    PORT=8501  # Default port for Streamlit
else
    PORT=$1
fi

echo "=== Pengujian Konektivitas untuk Aplikasi pada Port $PORT ==="

# Periksa apakah ada proses yang berjalan pada port tersebut
echo -e "\n[1/5] Memeriksa proses pada port $PORT..."
if lsof -i:$PORT &>/dev/null; then
    echo "✅ Proses ditemukan pada port $PORT:"
    lsof -i:$PORT
else
    echo "❌ Tidak ada proses yang berjalan pada port $PORT!"
    echo "Aplikasi mungkin belum dijalankan. Jalankan 'bash debug_run.sh $PORT' terlebih dahulu."
    exit 1
fi

# Uji koneksi localhost
echo -e "\n[2/5] Menguji koneksi ke localhost:$PORT..."
if curl -s --connect-timeout 5 http://localhost:$PORT > /dev/null; then
    echo "✅ Koneksi ke localhost:$PORT berhasil."
else
    echo "❌ Tidak dapat terhubung ke localhost:$PORT!"
    echo "Periksa apakah aplikasi berjalan dengan benar."
fi

# Ambil alamat IP dan uji koneksi langsung ke IP:PORT
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo -e "\n[3/5] Menguji koneksi ke $IP_ADDRESS:$PORT..."
if curl -s --connect-timeout 5 http://$IP_ADDRESS:$PORT > /dev/null; then
    echo "✅ Koneksi ke $IP_ADDRESS:$PORT berhasil."
else
    echo "❌ Tidak dapat terhubung ke $IP_ADDRESS:$PORT!"
    echo "Periksa firewall dan binding aplikasi."
fi

# Periksa konfigurasi nginx
echo -e "\n[4/5] Memeriksa konfigurasi Nginx..."
if command -v nginx &>/dev/null; then
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx aktif."
        
        if grep -q "proxy_pass.*localhost:$PORT" /etc/nginx/sites-enabled/* 2>/dev/null; then
            echo "✅ Konfigurasi proxy untuk port $PORT ditemukan di Nginx."
            
            # Coba akses melalui Nginx (port 80)
            echo -e "\n[5/5] Menguji koneksi melalui Nginx (http://$IP_ADDRESS)..."
            if curl -s --connect-timeout 5 http://$IP_ADDRESS > /dev/null; then
                echo "✅ Koneksi melalui Nginx berhasil."
            else
                echo "❌ Tidak dapat terhubung melalui Nginx!"
                echo "Nginx mungkin tidak dapat meneruskan permintaan ke aplikasi."
                echo "Periksa log Nginx: tail -f /var/log/nginx/error.log"
            fi
        else
            echo "❌ Tidak ditemukan konfigurasi proxy untuk port $PORT di Nginx."
            echo "Jalankan 'sudo bash setup_nginx.sh $PORT' untuk mengkonfigurasi Nginx."
        fi
    else
        echo "❌ Nginx tidak aktif. Mulai dengan 'sudo systemctl start nginx'."
    fi
else
    echo "❌ Nginx tidak terinstal. Instal dengan 'sudo apt install nginx'."
fi

echo -e "\n=== Tips Pemecahan Masalah ==="
echo "1. Pastikan aplikasi berjalan dengan 'bash debug_run.sh $PORT'"
echo "2. Pastikan port $PORT tersedia dan tidak digunakan oleh aplikasi lain"
echo "3. Pastikan firewall mengizinkan koneksi ke port $PORT dan port 80"
echo "4. Periksa log Nginx: 'sudo tail -f /var/log/nginx/error.log'"
echo "5. Periksa konfigurasi Nginx: 'sudo nginx -T | grep $PORT'"
echo "6. Restart Nginx setelah perubahan: 'sudo systemctl restart nginx'"
