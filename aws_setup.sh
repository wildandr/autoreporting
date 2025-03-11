#!/bin/bash

echo "Setting up Flask application on AWS Ubuntu server..."

# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install required system packages
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libreoffice-common \
    libreoffice-writer \
    ufw

# Configure firewall to allow traffic on the application port
echo "Configuring firewall to allow traffic on port 8502..."
sudo ufw allow 8502/tcp
sudo ufw --force enable

# Create virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install required Python packages
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create systemd service file for running the Flask app
echo "Creating systemd service for the Flask application..."
cat << EOF | sudo tee /etc/systemd/system/flask_app.service
[Unit]
Description=Flask Application Service
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin"
ExecStart=$(pwd)/venv/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable flask_app
sudo systemctl start flask_app

echo "Setup completed! Your Flask application should now be running as a service."
echo "To check the status, run: sudo systemctl status flask_app"
echo "To view logs, run: sudo journalctl -u flask_app"
echo "You can access your application at: http://YOUR_SERVER_IP:8502"
