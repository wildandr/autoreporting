#!/bin/bash

echo "=== Streamlit Configuration Update ==="

# Check if user is root
if [ "$(whoami)" != "root" ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Parameters
PORT=8080
APP_DIR="/root/daily_report_app"
CONFIG_DIR="$APP_DIR/.streamlit"
SERVICE_FILE="/etc/systemd/system/daily-report.service"

# Create Streamlit config directory
mkdir -p "$CONFIG_DIR"

# Create Streamlit config file with additional settings
cat > "$CONFIG_DIR/config.toml" << EOL
[server]
port = $PORT
address = "0.0.0.0"
headless = true
enableCORS = false
enableXsrfProtection = false

[browser]
serverAddress = "localhost"
gatherUsageStats = false
EOL

# Update systemd service file to use the config
cat > "$SERVICE_FILE" << EOL
[Unit]
Description=Daily Report Streamlit App
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/streamlit run streamlit.py --server.address=0.0.0.0 --server.port=$PORT --server.headless=true --server.enableCORS=false --server.enableXsrfProtection=false
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Restart service
systemctl daemon-reload
systemctl restart daily-report

# Ensure firewall allows the port
if command -v ufw &>/dev/null; then
    ufw allow $PORT/tcp
fi

echo "Configuration updated. Testing connectivity..."

# Wait a moment for the service to start
sleep 5

# Test connection
curl -s -m 5 http://localhost:$PORT > /dev/null
if [ $? -eq 0 ]; then
    echo "SUCCESS: Streamlit is responding locally."
    echo "External access should now work if network/firewall settings are correct."
else
    echo "WARNING: Local connection test failed. Service might still be starting up."
fi

echo "To verify access, try: curl -v http://localhost:$PORT"
echo "Check service status with: systemctl status daily-report"

# Get IP addresses
echo -e "\nYou can access the application at:"
ip -4 addr show | grep inet | awk '{print "http://" $2}' | cut -d'/' -f1 | sed "s/$/:$PORT/"
