#!/bin/bash

# Script untuk backup dan restore konfigurasi aplikasi Daily Report Generator
# Usage: 
# - Backup: sudo bash backup_restore.sh backup
# - Restore: sudo bash backup_restore.sh restore /path/to/backup.tar.gz

set -e

# Memeriksa apakah dijalankan sebagai root
if [ "$(whoami)" != "root" ]; then
    echo "Script ini harus dijalankan sebagai root. Gunakan sudo."
    exit 1
fi

ACTION=$1
BACKUP_PATH="/root/daily_report_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
APP_DIR="/root/autoreporting"
RESTORE_FILE=$2

case $ACTION in
    backup)
        echo "=== Backup Konfigurasi Aplikasi Daily Report Generator ==="
        echo "Membuat backup ke: $BACKUP_PATH"
        
        # Buat direktori temporary untuk backup
        TEMP_DIR=$(mktemp -d)
        
        # Copy file aplikasi
        echo "[1/4] Menyalin file aplikasi..."
        mkdir -p $TEMP_DIR/app
        cp -r $APP_DIR/* $TEMP_DIR/app/ 2>/dev/null || true
        
        # Copy konfigurasi Nginx
        echo "[2/4] Menyalin konfigurasi Nginx..."
        mkdir -p $TEMP_DIR/nginx
        cp /etc/nginx/sites-available/streamlit $TEMP_DIR/nginx/ 2>/dev/null || true
        
        # Copy service file
        echo "[3/4] Menyalin file service..."
        mkdir -p $TEMP_DIR/systemd
        cp /etc/systemd/system/daily-report.service $TEMP_DIR/systemd/ 2>/dev/null || true
        
        # Buat file info
        echo "[4/4] Menyimpan informasi sistem..."
        {
            echo "Backup created at: $(date)"
            echo "Hostname: $(hostname)"
            echo "IP: $(hostname -I)"
            echo "System: $(uname -a)"
            echo "Nginx status: $(systemctl is-active nginx)"
            echo "App status: $(systemctl is-active daily-report)"
        } > $TEMP_DIR/backup_info.txt
        
        # Buat archive
        tar -czf $BACKUP_PATH -C $TEMP_DIR .
        
        # Hapus direktori temporary
        rm -rf $TEMP_DIR
        
        echo "=== Backup Selesai ==="
        echo "File backup: $BACKUP_PATH"
        echo "Untuk restore, gunakan: sudo bash backup_restore.sh restore $BACKUP_PATH"
        ;;
        
    restore)
        if [ -z "$RESTORE_FILE" ]; then
            echo "Error: File backup tidak ditentukan"
            echo "Penggunaan: sudo bash backup_restore.sh restore /path/to/backup.tar.gz"
            exit 1
        fi
        
        if [ ! -f "$RESTORE_FILE" ]; then
            echo "Error: File backup tidak ditemukan: $RESTORE_FILE"
            exit 1
        fi
        
        echo "=== Restore Konfigurasi dari Backup ==="
        echo "Menggunakan file backup: $RESTORE_FILE"
        
        # Buat direktori temporary untuk restore
        TEMP_DIR=$(mktemp -d)
        
        # Ekstrak backup
        echo "[1/5] Mengekstrak file backup..."
        tar -xzf $RESTORE_FILE -C $TEMP_DIR
        
        # Tampilkan informasi backup
        echo "[2/5] Informasi backup:"
        cat $TEMP_DIR/backup_info.txt
        
        # Konfirmasi restore
        read -p "Lanjutkan restore? [y/N] " CONFIRM
        if [[ $CONFIRM != [yY] ]]; then
            echo "Restore dibatalkan."
            rm -rf $TEMP_DIR
            exit 0
        fi
        
        # Restore file aplikasi
        echo "[3/5] Memulihkan file aplikasi..."
        mkdir -p $APP_DIR
        cp -r $TEMP_DIR/app/* $APP_DIR/ 2>/dev/null || true
        
        # Restore konfigurasi Nginx
        echo "[4/5] Memulihkan konfigurasi Nginx..."
        if [ -f "$TEMP_DIR/nginx/streamlit" ]; then
            cp $TEMP_DIR/nginx/streamlit /etc/nginx/sites-available/
            ln -sf /etc/nginx/sites-available/streamlit /etc/nginx/sites-enabled/
            systemctl restart nginx
        fi
        
        # Restore service file
        echo "[5/5] Memulihkan file service aplikasi..."
        if [ -f "$TEMP_DIR/systemd/daily-report.service" ]; then
            cp $TEMP_DIR/systemd/daily-report.service /etc/systemd/system/
            systemctl daemon-reload
            systemctl enable daily-report
            systemctl restart daily-report
        fi
        
        # Hapus direktori temporary
        rm -rf $TEMP_DIR
        
        echo "=== Restore Selesai ==="
        echo "Aplikasi telah dipulihkan dari backup."
        ;;
        
    *)
        echo "Penggunaan:"
        echo "- Backup: sudo bash backup_restore.sh backup"
        echo "- Restore: sudo bash backup_restore.sh restore /path/to/backup.tar.gz"
        exit 1
        ;;
esac
