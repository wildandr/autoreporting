#!/bin/bash

# Script instalasi otomatis untuk Daily Report Generator
# Usage: bash install.sh [username] [port]

set -e

echo "Current user: $(whoami)"
echo "User ID: $(id)"

# Gunakan parameter username jika disediakan, jika tidak gunakan root jika sudah sebagai root
if [ -z "$1" ]; then
  if [ "$(whoami)" = "root" ]; then
    USERNAME="root"
  else
    USERNAME=$(whoami)
  fi
else
  USERNAME=$1
fi

# Gunakan port kustom jika disediakan, jika tidak gunakan 8501
if [ -z "$2" ]; then
  PORT=8501
else
  PORT=$2
fi

# Pastikan username valid
if ! id "$USERNAME" &>/dev/null; then
  echo "Error: User $USERNAME tidak ditemukan. Silakan berikan username yang valid."
  exit 1
fi

# Direktori home user
USER_HOME=$(eval echo ~$USERNAME)
APP_DIR="$USER_HOME/daily_report_app"

echo "=== Daily Report Generator - Installer ==="
echo "Username: $USERNAME"
echo "App directory: $APP_DIR"
echo "Port: $PORT"

echo -e "\n[1/7] Update sistem dan install dependencies..."
# Cek apakah perlu sudo
if [ "$(whoami)" != "root" ]; then
  sudo apt update
  sudo apt install -y python3 python3-pip python3-venv libreoffice
else
  apt update
  apt install -y python3 python3-pip python3-venv libreoffice
fi

echo -e "\n[2/7] Membuat direktori aplikasi..."
mkdir -p $APP_DIR
cp streamlit.py "$APP_DIR/"
if [ -f "Weekly Daily Report Wildan Dzaky Ramadhani.docx" ]; then
  cp "Weekly Daily Report Wildan Dzaky Ramadhani.docx" "$APP_DIR/"
else
  echo "WARNING: Template dokumen tidak ditemukan. Pastikan untuk menyalin file template ke direktori aplikasi."
fi

echo -e "\n[3/7] Mengatur kepemilikan direktori..."
if [ "$(whoami)" != "root" ]; then
  sudo chown -R $USERNAME:$USERNAME $APP_DIR
else
  chown -R $USERNAME:$USERNAME $APP_DIR
fi

echo -e "\n[4/7] Membuat virtual environment..."
if [ "$USERNAME" = "$(whoami)" ]; then
  cd $APP_DIR && python3 -m venv venv
else
  su - $USERNAME -c "cd $APP_DIR && python3 -m venv venv"
fi

echo -e "\n[5/7] Menginstal library yang diperlukan..."
if [ "$USERNAME" = "$(whoami)" ]; then
  cd $APP_DIR && source venv/bin/activate && pip install streamlit python-docx pandas requests
else
  su - $USERNAME -c "cd $APP_DIR && source venv/bin/activate && pip install streamlit python-docx pandas requests"
fi

echo -e "\n[6/7] Membuat service systemd..."
SERVICE_FILE="/etc/systemd/system/daily-report.service"

# Buat konten service
SERVICE_CONTENT="[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=$USERNAME
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target"

# Tulis ke file service
if [ "$(whoami)" != "root" ]; then
  echo "$SERVICE_CONTENT" | sudo tee $SERVICE_FILE > /dev/null
else
  echo "$SERVICE_CONTENT" > $SERVICE_FILE
fi

echo -e "\n[7/7] Mengaktifkan dan memulai service..."
if [ "$(whoami)" != "root" ]; then
  sudo systemctl daemon-reload
  sudo systemctl enable daily-report
  sudo systemctl start daily-report
else
  systemctl daemon-reload
  systemctl enable daily-report
  systemctl start daily-report
fi

# Cek status firewall
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
  echo -e "\nMembuka port $PORT di firewall UFW..."
  if [ "$(whoami)" != "root" ]; then
    sudo ufw allow $PORT/tcp
  else
    ufw allow $PORT/tcp
  fi
fi

# Ambil alamat IP server
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo -e "\n=== Instalasi Selesai! ==="
echo "Daily Report Generator telah diinstal dan dijalankan sebagai service."
echo -e "\nAnda dapat mengakses aplikasi di browser dengan alamat:"
echo "http://$IP_ADDRESS:$PORT"
echo -e "\nUntuk melihat status service:"
echo "sudo systemctl status daily-report"
echo -e "\nUntuk melihat log service:"
echo "sudo journalctl -u daily-report -f"
echo -e "\nInstalasi selesai!"
