#!/bin/bash

# Setup Nginx as reverse proxy for Streamlit
echo "=== Setting up Nginx as reverse proxy for Streamlit ==="

# Check if running as root
if [ "$(whoami)" != "root" ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Install Nginx if not already installed
echo "Installing Nginx..."
apt update
apt install -y nginx

# Get the Streamlit port (default 8080)
PORT=8080
if [ ! -z "$1" ]; then
    PORT=$1
fi

# Create Nginx configuration
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/streamlit << EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_buffering off;
    }
}
EOL

# Enable the site
ln -sf /etc/nginx/sites-available/streamlit /etc/nginx/sites-enabled/

# Test Nginx config
nginx -t

# Restart Nginx
systemctl restart nginx

# Open port 80 if firewall is active
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    echo "Opening port 80 in firewall..."
    ufw allow 80/tcp
fi

echo "=== Nginx setup complete ==="
echo "You can now access your Streamlit app at:"
echo "http://$(hostname -I | awk '{print $1}')"
echo "If you still have issues, check Nginx logs with: tail -f /var/log/nginx/error.log"
