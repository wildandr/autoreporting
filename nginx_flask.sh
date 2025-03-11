#!/bin/bash

# Configure Nginx as reverse proxy for Flask app
# Usage: bash nginx_flask.sh [port]

set -e

# Check if running as root
if [ "$(whoami)" != "root" ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Get the app port (default 8080)
if [ -z "$1" ]; then
    APP_PORT=8080
else
    APP_PORT=$1
fi

# Install Nginx if not already installed
echo "[1/4] Installing Nginx..."
apt update
apt install -y nginx

# Create Nginx configuration
echo "[2/4] Configuring Nginx..."
cat > /etc/nginx/sites-available/daily-report << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 300s;
    }
}
EOL

# Enable the site
echo "[3/4] Enabling the site configuration..."
ln -sf /etc/nginx/sites-available/daily-report /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
nginx -t

# Restart Nginx
echo "[4/4] Restarting Nginx..."
systemctl restart nginx

# Open HTTP port if firewall is active
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo "Opening port 80 in firewall..."
    ufw allow 80/tcp
fi

IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "=== Nginx setup complete ==="
echo "You can now access your application at:"
echo "http://$IP_ADDRESS"
echo ""
echo "The Flask app on port $APP_PORT is now being proxied through Nginx."
