#!/bin/bash
set -e

# ── Bootstrap script — runs on first EC2 boot ────────────────────────────────
# Installs Python, the FastAPI app, and starts it as a systemd service.
# Environment variables are injected by Terraform's templatefile() function.

# Update packages and install Python
yum update -y
yum install -y python3 python3-pip git

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Write the FastAPI app inline
# In a real project this would clone from Git — simplified here for clarity
cat > /opt/app/requirements.txt << 'REQUIREMENTS'
fastapi==0.115.0
uvicorn[standard]==0.30.6
psycopg2-binary==2.9.9
pydantic==2.9.2
REQUIREMENTS

# Install dependencies
pip3 install -r /opt/app/requirements.txt

# Write environment variables
cat > /opt/app/.env << ENV
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
APP_PORT=${app_port}
ENVIRONMENT=${environment}
ENV

cat > /opt/app/main.py << 'APPEOF'
${app_code}
APPEOF

# Create systemd service so the app restarts automatically
cat > /etc/systemd/system/portfolio-api.service << SERVICE
[Unit]
Description=Portfolio API FastAPI Service
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${app_port} --workers 1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
systemctl daemon-reload
systemctl enable portfolio-api
systemctl start portfolio-api

echo "Bootstrap complete — app started on port ${app_port}"
