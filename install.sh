#!/bin/bash

echo "Installing required system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    libreoffice-common \
    libreoffice-writer

# Create virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install required Python packages
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Installation completed successfully!"
echo "To run the application:"
echo "1. Activate the virtual environment: source venv/bin/activate"
echo "2. Run the application: python3 app.py"
echo "3. Open your browser and go to http://localhost:5000"
