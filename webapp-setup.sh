#!/bin/bash
# Setup script for webapp container (run inside container 101)
set -e

echo "=== Setting up jee.bz webapp ==="

# Install dependencies
apt-get update
apt-get install -y python3 python3-pip python3-venv curl debian-keyring debian-archive-keyring apt-transport-https

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Create webapp directory
mkdir -p /opt/webapp/static

# Create virtual environment and install Flask
cd /opt/webapp
python3 -m venv venv
./venv/bin/pip install flask gunicorn

# Copy app files (assumes they're in /tmp)
cp /tmp/app.py /opt/webapp/
cp /tmp/Caddyfile /etc/caddy/
cp /tmp/webapp.service /etc/systemd/system/

# Copy static assets if provided
[ -f /tmp/jee.bz.png ] && cp /tmp/jee.bz.png /opt/webapp/static/
[ -f /tmp/favicon.png ] && cp /tmp/favicon.png /opt/webapp/static/

# Create webapp user
useradd -r -s /bin/false webapp 2>/dev/null || true
chown -R webapp:webapp /opt/webapp

# Enable and start services
systemctl daemon-reload
systemctl enable webapp caddy
systemctl start webapp caddy

echo "=== Webapp setup complete ==="
echo "Configure Caddyfile with your domain and container IPs"
