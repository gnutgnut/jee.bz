#!/bin/bash
# Minecraft Spigot Server Installation Script
# Run this script INSIDE the LXC container (103)
# Mirrors the Fabric container (100) interface exactly

set -e

MINECRAFT_DIR="/opt/minecraft"
MINECRAFT_USER="minecraft"
MINECRAFT_VERSION="1.21.4"

echo "============================================"
echo "Minecraft Spigot Server Installation"
echo "============================================"

# Create minecraft user
echo "Creating minecraft user..."
if ! id -u ${MINECRAFT_USER} >/dev/null 2>&1; then
    useradd -r -m -U -d ${MINECRAFT_DIR} -s /bin/bash ${MINECRAFT_USER}
fi

# Install Java 21 (Adoptium for Debian 12)
echo "Installing Java 21 (Adoptium)..."
apt-get update
apt-get install -y curl wget git nano jq gnupg

# Adoptium repo (Debian 12 doesn't have openjdk-21 in default repos)
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y temurin-21-jdk

echo "Java version installed:"
java -version

# Create minecraft directory
echo "Setting up Minecraft directory..."
mkdir -p ${MINECRAFT_DIR}
cd ${MINECRAFT_DIR}

# Build Spigot using BuildTools
echo "Downloading BuildTools..."
mkdir -p /tmp/buildtools
cd /tmp/buildtools
wget -O BuildTools.jar "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"

echo "Building Spigot ${MINECRAFT_VERSION} (this takes a while)..."
java -jar BuildTools.jar --rev ${MINECRAFT_VERSION}

# Find the built jar
SPIGOT_JAR=$(ls spigot-*.jar 2>/dev/null | head -1)
if [ -z "$SPIGOT_JAR" ]; then
    echo "ERROR: Spigot build failed! No spigot jar found."
    exit 1
fi

echo "Copying ${SPIGOT_JAR} to ${MINECRAFT_DIR}..."
cp "$SPIGOT_JAR" "${MINECRAFT_DIR}/spigot.jar"
cd ${MINECRAFT_DIR}
rm -rf /tmp/buildtools

# Accept EULA
echo "Accepting Minecraft EULA..."
echo "eula=true" > eula.txt

# Create plugins directory (Spigot equivalent of mods/)
mkdir -p plugins

# Download GeyserMC and Floodgate (Bedrock client support)
echo "Downloading GeyserMC and Floodgate plugins..."
GEYSER_URL=$(curl -s "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest" | jq -r '.downloads.spigot.url // empty')
if [ -n "$GEYSER_URL" ]; then
    wget -q -O plugins/Geyser-Spigot.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
    echo "  Downloaded Geyser-Spigot.jar"
else
    echo "  Warning: Could not fetch Geyser download URL, downloading directly..."
    wget -q -O plugins/Geyser-Spigot.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" || echo "  Failed to download GeyserMC"
fi

FLOODGATE_URL=$(curl -s "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest" | jq -r '.downloads.spigot.url // empty')
if [ -n "$FLOODGATE_URL" ]; then
    wget -q -O plugins/floodgate-spigot.jar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
    echo "  Downloaded floodgate-spigot.jar"
else
    wget -q -O plugins/floodgate-spigot.jar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" || echo "  Failed to download Floodgate"
fi

echo ""
echo "GeyserMC notes:"
echo "  - Bedrock players connect on port 19132 (UDP) by default"
echo "  - Floodgate lets Bedrock players join without a Java account"
echo "  - Bedrock usernames get a '.' prefix by default (configurable)"
echo "  - Config: plugins/Geyser-Spigot/config.yml (generated on first run)"
echo ""

# Install unmined-cli for top-down map (same as Fabric container)
echo "Installing unmined-cli..."
curl -L -o /tmp/unmined-cli.tar.gz "https://unmined.blob.core.windows.net/files/unmined-cli_0.19.54-dev_linux-x64.tar.gz"
tar -xzf /tmp/unmined-cli.tar.gz -C ${MINECRAFT_DIR}
rm /tmp/unmined-cli.tar.gz

# Install Chunky for isometric renders (same as Fabric container)
echo "Installing Chunky renderer..."
mkdir -p /opt/chunky
cd /opt/chunky
curl -L -o ChunkyLauncher.jar "https://chunky-dev.github.io/docs/download/ChunkyLauncher.jar"
java -Dchunky.home=/opt/chunky -jar ChunkyLauncher.jar --update
java -Dchunky.home=/opt/chunky -jar ChunkyLauncher.jar -download-mc ${MINECRAFT_VERSION}
mkdir -p scenes
cd ${MINECRAFT_DIR}

# Install ImageMagick for image processing
apt-get install -y imagemagick

# Create server.properties (same settings as Fabric, just different MOTD)
echo "Creating server.properties..."
cat > server.properties << 'EOF'
#Minecraft server properties
accepts-transfers=false
allow-flight=false
allow-nether=true
broadcast-console-to-ops=true
broadcast-rcon-to-ops=true
difficulty=normal
enable-command-block=true
enable-jmx-monitoring=false
enable-query=false
enable-rcon=true
enable-status=true
enforce-secure-profile=true
enforce-whitelist=false
entity-broadcast-range-percentage=100
force-gamemode=false
function-permission-level=2
gamemode=survival
generate-structures=true
generator-settings={}
hardcore=false
hide-online-players=false
initial-disabled-packs=
initial-enabled-packs=vanilla
level-name=world
level-seed=7749012223296673
level-type=minecraft\:normal
log-ips=true
max-chained-neighbor-updates=1000000
max-players=10
max-tick-time=-1
max-world-size=29999984
motd=\u00A76jee.bz \u00A7r- Spigot 1.21.4
network-compression-threshold=256
online-mode=true
op-permission-level=4
pause-when-empty-seconds=60
player-idle-timeout=0
prevent-proxy-connections=false
pvp=true
query.port=25565
rate-limit=0
rcon.password=CHANGE_ME_BEFORE_USE
rcon.port=25575
region-file-compression=deflate
require-resource-pack=false
resource-pack=
resource-pack-id=
resource-pack-prompt=
resource-pack-sha1=
server-ip=
server-port=25565
simulation-distance=12
spawn-monsters=true
spawn-protection=16
sync-chunk-writes=true
use-native-transport=true
view-distance=16
white-list=true
EOF

# Create start.sh (same JVM flags, just launches spigot.jar)
cat > start.sh << 'EOF'
#!/bin/bash
java -Xms20G -Xmx20G \
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
  -XX:SurvivorRatio=32 \
  -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 \
  -Dusing.aikars.flags=https://mcflags.emc.gs \
  -Daikars.new.flags=true \
  -jar spigot.jar nogui
EOF
chmod +x start.sh

# Create systemd service (same name: minecraft.service)
cat > /etc/systemd/system/minecraft.service << EOF
[Unit]
Description=Minecraft Spigot Server
After=network.target

[Service]
Type=simple
User=${MINECRAFT_USER}
WorkingDirectory=${MINECRAFT_DIR}
ExecStart=/bin/bash ${MINECRAFT_DIR}/start.sh
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Copy whitelist and ops from shared mount (if available from Fabric container)
if [ -f /mnt/shared/whitelist.json ]; then
    cp /mnt/shared/whitelist.json ${MINECRAFT_DIR}/whitelist.json
    echo "Copied whitelist from shared mount"
else
    # Default whitelist
    cat > whitelist.json << 'EOF'
[
  {
    "uuid": "e0c68850-14fa-4f5d-87b5-bf6093326e14",
    "name": "Detcader_"
  }
]
EOF
fi

if [ -f /mnt/shared/ops.json ]; then
    cp /mnt/shared/ops.json ${MINECRAFT_DIR}/ops.json
    echo "Copied ops from shared mount"
else
    cat > ops.json << 'EOF'
[
  {
    "uuid": "e0c68850-14fa-4f5d-87b5-bf6093326e14",
    "name": "Detcader_",
    "level": 4,
    "bypassesPlayerLimit": false
  }
]
EOF
fi

# Create backup directory
mkdir -p ${MINECRAFT_DIR}/backups

# Set permissions
chown -R ${MINECRAFT_USER}:${MINECRAFT_USER} ${MINECRAFT_DIR}

# Enable service (but don't start - use switch-mc.sh)
systemctl daemon-reload
systemctl enable minecraft.service

echo ""
echo "============================================"
echo "Installation Complete!"
echo "============================================"
echo ""
echo "Minecraft directory: ${MINECRAFT_DIR}"
echo "Service name: minecraft.service"
echo "Jar: spigot.jar"
echo ""
echo "IMPORTANT: This container shares the same interface as the Fabric container."
echo "  - Same service name: minecraft"
echo "  - Same paths: /opt/minecraft/, /mnt/shared/"
echo "  - Same port: 25565"
echo "  - Same management commands: systemctl start/stop/restart minecraft"
echo ""
echo "Use switch-mc.sh on the Proxmox host to swap between Fabric and Spigot."
echo ""
echo "Don't forget to:"
echo "  1. Change RCON password in server.properties"
echo "  2. Copy render scripts (render_map.sh, render_isometric.sh, etc.)"
echo "  3. Set up cron jobs (same as Fabric container)"
echo "  4. Set up static DHCP for this container's IP"
