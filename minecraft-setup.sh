#!/bin/bash
# Minecraft Fabric Server Installation Script
# Run this script INSIDE the LXC container

set -e

MINECRAFT_DIR="/opt/minecraft"
MINECRAFT_USER="minecraft"
FABRIC_INSTALLER_VERSION="1.0.1"
MINECRAFT_VERSION="1.21.4"  # Change to desired version
FABRIC_VERSION=""  # Leave empty for latest

echo "============================================"
echo "Minecraft Fabric Server Installation"
echo "============================================"

# Create minecraft user
echo "Creating minecraft user..."
if ! id -u ${MINECRAFT_USER} >/dev/null 2>&1; then
    useradd -r -m -U -d ${MINECRAFT_DIR} -s /bin/bash ${MINECRAFT_USER}
fi

# Install Java 21 and required tools
echo "Installing Java 21 and dependencies..."
apt-get update
apt-get install -y openjdk-21-jdk-headless curl jq

# Verify Java installation
if ! java -version >/dev/null 2>&1; then
    echo "ERROR: Java installation failed!"
    exit 1
fi

echo "Java version installed:"
java -version

# Create minecraft directory
echo "Setting up Minecraft directory..."
mkdir -p ${MINECRAFT_DIR}
cd ${MINECRAFT_DIR}

# Download Fabric installer
echo "Downloading Fabric installer..."
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"
if ! wget -O fabric-installer.jar ${FABRIC_INSTALLER_URL}; then
    echo "ERROR: Failed to download Fabric installer"
    exit 1
fi

# Install Fabric server
echo "Installing Fabric server for Minecraft ${MINECRAFT_VERSION}..."
if [ -z "${FABRIC_VERSION}" ]; then
    if ! java -jar fabric-installer.jar server -mcversion ${MINECRAFT_VERSION} -downloadMinecraft; then
        echo "ERROR: Fabric server installation failed!"
        echo "Possible causes:"
        echo "  - Invalid Minecraft version: ${MINECRAFT_VERSION}"
        echo "  - Network issues"
        echo "  - Insufficient disk space"
        exit 1
    fi
else
    if ! java -jar fabric-installer.jar server -mcversion ${MINECRAFT_VERSION} -loader ${FABRIC_VERSION} -downloadMinecraft; then
        echo "ERROR: Fabric server installation failed!"
        exit 1
    fi
fi

# Verify fabric-server-launch.jar was created
if [ ! -f "fabric-server-launch.jar" ]; then
    echo "ERROR: fabric-server-launch.jar not found after installation!"
    exit 1
fi

echo "Fabric server installed successfully!"

# Accept EULA
echo "Accepting Minecraft EULA..."
echo "eula=true" > eula.txt

# Create mods directory
mkdir -p mods

# Download performance mods
echo "Downloading performance mods..."
MODRINTH_API="https://api.modrinth.com/v2"

download_mod() {
    local mod_id=$1
    local mod_name=$2
    echo "  - Downloading ${mod_name}..."

    # Get latest version for Minecraft version and Fabric with better error handling
    local api_response=$(curl -s "${MODRINTH_API}/project/${mod_id}/version?loaders=[%22fabric%22]&game_versions=[%22${MINECRAFT_VERSION}%22]")

    if [ -z "$api_response" ]; then
        echo "    Warning: API request failed for ${mod_name}"
        return 1
    fi

    # Use jq for better JSON parsing if available, fallback to grep
    local download_url=""
    if command -v jq >/dev/null 2>&1; then
        download_url=$(echo "$api_response" | jq -r '.[0].files[0].url // empty' 2>/dev/null)
    else
        download_url=$(echo "$api_response" | grep -o '"url":"[^"]*' | head -1 | cut -d'"' -f4)
    fi

    if [ -n "${download_url}" ]; then
        if wget -q -P mods "${download_url}"; then
            echo "    ✓ Downloaded ${mod_name}"
        else
            echo "    Warning: Download failed for ${mod_name}"
        fi
    else
        echo "    Warning: Could not find ${mod_name} for Minecraft ${MINECRAFT_VERSION}"
    fi
}

# Download key performance mods
download_mod "gvQqBUqZ" "Lithium"
download_mod "H8CaAYZC" "Starlight"
download_mod "uXXizFIs" "FerriteCore"
download_mod "VSNURh3q" "C2ME"
download_mod "P7dR8mSH" "Fabric API"
download_mod "swbUV1cr" "BlueMap"

# Install Chunky for isometric renders
echo "Installing Chunky renderer..."
mkdir -p /opt/chunky
cd /opt/chunky
curl -L -o ChunkyLauncher.jar "https://chunky-dev.github.io/docs/download/ChunkyLauncher.jar"
java -Dchunky.home=/opt/chunky -jar ChunkyLauncher.jar --update
java -Dchunky.home=/opt/chunky -jar ChunkyLauncher.jar -download-mc ${MINECRAFT_VERSION}
mkdir -p scenes
cd ${MINECRAFT_DIR}

# Install unmined-cli for top-down map
echo "Installing unmined-cli..."
curl -L -o /tmp/unmined-cli.tar.gz "https://unmined.blob.core.windows.net/files/unmined-cli_0.19.54-dev_linux-x64.tar.gz"
tar -xzf /tmp/unmined-cli.tar.gz -C ${MINECRAFT_DIR}
rm /tmp/unmined-cli.tar.gz

# Install ImageMagick for image processing
apt-get install -y imagemagick

# Create optimized server.properties
echo "Creating server.properties..."
cat > server.properties << 'EOF'
# Minecraft Server Properties
# High-performance configuration

# Server Settings
server-port=25565
server-ip=
level-name=world
gamemode=survival
difficulty=normal
max-players=10
online-mode=true
white-list=false
motd=§6Fabric Server - Powered by Proxmox

# Performance Settings
view-distance=16
simulation-distance=12
max-tick-time=60000
network-compression-threshold=256

# World Settings
allow-nether=true
allow-flight=false
spawn-protection=16
spawn-monsters=true
spawn-animals=true
spawn-npcs=true
generate-structures=true
level-seed=
level-type=minecraft\:normal

# RCON (for remote management)
enable-rcon=true
rcon.port=25575
rcon.password=minecraft_rcon_password_change_me

# Other
enable-command-block=true
function-permission-level=2
op-permission-level=4
pvp=true
enforce-whitelist=false
EOF

# Create optimized JVM startup script
echo "Creating startup script with optimized JVM arguments..."
cat > start.sh << 'EOF'
#!/bin/bash
# Optimized startup script for Fabric server with 12GB heap

java -Xms12G -Xmx12G \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC \
  -XX:+AlwaysPreTouch \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 \
  -XX:G1HeapWastePercent=5 \
  -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 \
  -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 \
  -Dusing.aikars.flags=https://mcflags.emc.gs \
  -Daikars.new.flags=true \
  -jar fabric-server-launch.jar nogui
EOF

chmod +x start.sh

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/minecraft.service << EOF
[Unit]
Description=Minecraft Fabric Server
After=network.target

[Service]
Type=simple
User=${MINECRAFT_USER}
WorkingDirectory=${MINECRAFT_DIR}
ExecStart=/bin/bash ${MINECRAFT_DIR}/start.sh
Restart=on-failure
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ${MINECRAFT_USER}:${MINECRAFT_USER} ${MINECRAFT_DIR}

# Configure firewall
echo "Configuring firewall..."
ufw allow 25565/tcp comment 'Minecraft'
ufw allow 25575/tcp comment 'Minecraft RCON'
ufw --force enable

# Enable and start service
echo "Enabling Minecraft service..."
systemctl daemon-reload
systemctl enable minecraft.service

echo ""
echo "============================================"
echo "Installation Complete!"
echo "============================================"
echo ""
echo "Minecraft directory: ${MINECRAFT_DIR}"
echo "Service name: minecraft.service"
echo ""
echo "Management commands:"
echo "  Start server:   systemctl start minecraft"
echo "  Stop server:    systemctl stop minecraft"
echo "  Restart server: systemctl restart minecraft"
echo "  View logs:      journalctl -u minecraft -f"
echo "  Console access: screen -r (if using screen)"
echo ""
echo "Server files:"
echo "  Config:  ${MINECRAFT_DIR}/server.properties"
echo "  Mods:    ${MINECRAFT_DIR}/mods/"
echo "  Worlds:  ${MINECRAFT_DIR}/world/"
echo ""
echo "IMPORTANT: Change RCON password in server.properties!"
echo ""
read -p "Start Minecraft server now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Minecraft server..."
    systemctl start minecraft
    echo "Server starting... Check logs with: journalctl -u minecraft -f"
fi
