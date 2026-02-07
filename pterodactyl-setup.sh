#!/bin/bash
# Pterodactyl Panel Installation Script (Simplified Alternative)
# This installs a lightweight web management panel for Minecraft
# For full Pterodactyl, see: https://pterodactyl.io/project/introduction.html

set -e

echo "============================================"
echo "MCSManager Web Panel Installation"
echo "============================================"
echo ""
echo "Installing lightweight MCSManager as an alternative to Pterodactyl"
echo "MCSManager provides web-based server management without heavy dependencies"
echo ""

# Install Node.js
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Create mcsmanager user
if ! id -u mcsmanager >/dev/null 2>&1; then
    useradd -r -m -U -d /opt/mcsmanager -s /bin/bash mcsmanager
fi

# Install MCSManager
echo "Installing MCSManager..."
cd /opt/mcsmanager

# Download and install daemon
mkdir -p daemon web
cd daemon
wget -qO- https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz | tar -zxf -

cd ../web
wget -qO- https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_web_linux_release.tar.gz | tar -zxf -

# Set permissions
chown -R mcsmanager:mcsmanager /opt/mcsmanager

# Create systemd services
echo "Creating systemd services..."

cat > /etc/systemd/system/mcsm-daemon.service << 'EOF'
[Unit]
Description=MCSManager Daemon
After=network.target

[Service]
Type=simple
User=mcsmanager
WorkingDirectory=/opt/mcsmanager/daemon
ExecStart=/usr/bin/node app.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/mcsm-web.service << 'EOF'
[Unit]
Description=MCSManager Web Panel
After=network.target mcsm-daemon.service

[Service]
Type=simple
User=mcsmanager
WorkingDirectory=/opt/mcsmanager/web
ExecStart=/usr/bin/node app.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall
echo "Configuring firewall..."
ufw allow 23333/tcp comment 'MCSManager Daemon'
ufw allow 24444/tcp comment 'MCSManager Web'

# Enable services
systemctl daemon-reload
systemctl enable mcsm-daemon mcsm-web
systemctl start mcsm-daemon mcsm-web

echo ""
echo "============================================"
echo "MCSManager Installation Complete!"
echo "============================================"
echo ""
echo "Access the web panel at:"
echo "  http://YOUR_SERVER_IP:24444"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: 123456"
echo ""
echo "IMPORTANT: Change the default password immediately!"
echo ""
echo "To add your Minecraft server:"
echo "  1. Log in to the web panel"
echo "  2. Go to 'Instances' > 'Create Instance'"
echo "  3. Select 'Minecraft Java Edition'"
echo "  4. Point to /opt/minecraft directory"
echo "  5. Set startup command: bash start.sh"
echo ""
echo "Services:"
echo "  Web Panel: systemctl status mcsm-web"
echo "  Daemon:    systemctl status mcsm-daemon"
echo ""
echo "NOTE: For full Pterodactyl installation (more features but complex),"
echo "see: https://pterodactyl.io/panel/1.0/getting_started.html"
