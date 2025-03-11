#!/bin/bash

echo "=== Streamlit Connection Diagnostics Tool ==="
echo "Checking server configuration and network settings..."

# Check if port is open
PORT=8080
echo -e "\n[1] Checking if port $PORT is listening:"
netstat -tuln | grep ":$PORT"
if [ $? -ne 0 ]; then
    echo "ERROR: Port $PORT is not listening. Streamlit may not be running properly."
    echo "Check service status with: sudo systemctl status daily-report"
else
    echo "SUCCESS: Port $PORT is listening."
fi

# Check firewall status
echo -e "\n[2] Checking firewall status:"
if command -v ufw &>/dev/null; then
    ufw status | grep "$PORT"
    echo "UFW is active. Checking for port $PORT:"
    if ufw status | grep -q "$PORT.*ALLOW"; then
        echo "SUCCESS: Port $PORT is allowed through UFW."
    else
        echo "WARNING: Port $PORT may not be allowed through UFW."
        echo "Run: sudo ufw allow $PORT/tcp"
    fi
else
    echo "UFW is not installed or not enabled."
fi

# Check cloud provider security groups if applicable
echo -e "\n[3] Checking for cloud provider:"
if [ -d /sys/class/dmi/id/ ]; then
    if grep -q "Alibaba Cloud" /sys/class/dmi/id/product_name 2>/dev/null; then
        echo "Detected Alibaba Cloud. Please check security groups in the Alibaba Cloud console."
        echo "Make sure port $PORT is allowed in your ECS security group."
    elif grep -q "Amazon EC2" /sys/class/dmi/id/product_name 2>/dev/null; then
        echo "Detected AWS EC2. Please check security groups in the AWS console."
        echo "Make sure port $PORT is allowed in your EC2 security group."
    fi
fi

# Check the actual access
echo -e "\n[4] Testing local connection to Streamlit:"
curl -s -m 3 http://localhost:$PORT > /dev/null
if [ $? -eq 0 ]; then
    echo "SUCCESS: Streamlit is responding on localhost."
else
    echo "ERROR: Cannot connect to Streamlit on localhost."
    echo "This suggests the application is not running properly."
fi

# Show IP addresses
echo -e "\n[5] Available network interfaces and IP addresses:"
ip -4 addr show | grep inet

echo -e "\n[6] Streamlit process status:"
ps aux | grep streamlit | grep -v grep

echo -e "\n=== Recommendations ==="
echo "1. If using a cloud provider, check security groups/firewall settings"
echo "2. Try accessing the application using the private IP if connecting from the same network"
echo "3. Check if your server has a public IP that is accessible from the internet"
echo "4. To restart the service: sudo systemctl restart daily-report"
echo "5. To view more detailed logs: sudo journalctl -u daily-report -f"
