# Troubleshooting Guide for Flask App on AWS

## Connection Timeout Issues

If you're experiencing a connection timeout when trying to access your application:

### 1. Check if the Flask server is running

```bash
sudo systemctl status flask_app
```

If not running, start it:

```bash
sudo systemctl start flask_app
```

### 2. Check server logs

```bash
sudo journalctl -u flask_app -n 50 --no-pager
```

### 3. Verify firewall settings

Make sure the port is open:

```bash
sudo ufw status
```

Add the rule if needed:

```bash
sudo ufw allow 8502/tcp
sudo ufw reload
```

### 4. Check AWS Security Group

1. Go to AWS Console > EC2 > Instances > Select your instance
2. Go to Security tab > Security groups
3. Edit inbound rules and make sure there's a rule allowing traffic on port 8502

### 5. Test the server locally

Test if the server responds locally on the VPS:

```bash
curl http://localhost:8502
```

### 6. Check for process using port

```bash
sudo lsof -i :8502
```

### 7. Run the server manually for debugging

```bash
cd /path/to/your/app
source venv/bin/activate
python server_check.py
```

## Quick Fix Commands

If you need to restart everything:

```bash
sudo systemctl restart flask_app
```

If you need to run the server manually:

```bash
cd /path/to/your/app
source venv/bin/activate
python app.py
```
