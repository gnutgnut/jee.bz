#!/bin/bash
# Setup script for Uptime Kuma container (run inside container 102)
set -e

echo "=== Setting up Uptime Kuma ==="

# Install Node.js 20
apt-get update
apt-get install -y ca-certificates curl gnupg git
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "Node.js version: $(node --version)"

# Clone and setup Uptime Kuma
cd /opt
git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
npm run setup

# Create systemd service
cat > /etc/systemd/system/uptime-kuma.service << 'EOF'
[Unit]
Description=Uptime Kuma
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/uptime-kuma
ExecStart=/usr/bin/node server/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
systemctl daemon-reload
systemctl enable uptime-kuma
systemctl start uptime-kuma

echo "=== Uptime Kuma setup complete ==="
echo "Access at http://<container-ip>:3001"
echo "Set up reverse proxy in Caddy for public access"
