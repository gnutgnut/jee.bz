#!/bin/bash
# Proxmox Firewall Configuration for Minecraft Server
# Run this script ON THE PROXMOX HOST

set -e

CTID=100  # Change to match your container ID

echo "============================================"
echo "Proxmox Firewall Configuration"
echo "============================================"
echo ""
echo "Configuring firewall rules for container ${CTID}"
echo ""

# Enable firewall at datacenter level (if not already enabled)
echo "Checking datacenter firewall status..."

# Backup existing firewall config if it exists
if [ -f /etc/pve/firewall/cluster.fw ]; then
    echo "Backing up existing datacenter firewall config..."
    cp /etc/pve/firewall/cluster.fw /etc/pve/firewall/cluster.fw.backup.$(date +%Y%m%d_%H%M%S)
fi

if ! grep -q "^enable: 1" /etc/pve/firewall/cluster.fw 2>/dev/null; then
    echo "Enabling datacenter firewall..."
    cat > /etc/pve/firewall/cluster.fw << 'EOF'
[OPTIONS]
enable: 1

[RULES]
# Allow SSH
IN ACCEPT -p tcp -dport 22 -log nolog

# Allow Proxmox Web UI
IN ACCEPT -p tcp -dport 8006 -log nolog

# Allow ping
IN ACCEPT -p icmp -log nolog
EOF
else
    echo "Datacenter firewall already configured"
fi

# Check if container exists
if ! pct status ${CTID} >/dev/null 2>&1; then
    echo "WARNING: Container ${CTID} does not exist yet."
    echo "Firewall rules will be created but won't apply until container is created."
fi

# Backup existing container firewall if it exists
if [ -f /etc/pve/firewall/${CTID}.fw ]; then
    echo "Backing up existing container firewall config..."
    cp /etc/pve/firewall/${CTID}.fw /etc/pve/firewall/${CTID}.fw.backup.$(date +%Y%m%d_%H%M%S)
fi

# Configure container-specific firewall rules
echo "Configuring container ${CTID} firewall..."
cat > /etc/pve/firewall/${CTID}.fw << 'EOF'
[OPTIONS]
enable: 1
ndp: 1
dhcp: 1
macfilter: 0
ipfilter: 0
log_level_in: nolog
log_level_out: nolog

[RULES]
# Minecraft Server
IN ACCEPT -p tcp -dport 25565 -log nolog -comment "Minecraft Game Port"

# Minecraft RCON (for remote console access)
IN ACCEPT -p tcp -dport 25575 -log nolog -comment "Minecraft RCON"

# MCSManager Web Panel
IN ACCEPT -p tcp -dport 24444 -log nolog -comment "MCSManager Web UI"

# MCSManager Daemon
IN ACCEPT -p tcp -dport 23333 -log nolog -comment "MCSManager Daemon"

# SSH (if you want direct SSH to container)
# IN ACCEPT -p tcp -dport 22 -log nolog -comment "SSH"

# Allow all outbound traffic
OUT ACCEPT -log nolog

# Allow established connections
IN ACCEPT -p tcp -m conntrack --ctstate ESTABLISHED,RELATED -log nolog
IN ACCEPT -p udp -m conntrack --ctstate ESTABLISHED,RELATED -log nolog
EOF

echo ""
echo "Firewall rules configured successfully!"
echo ""
echo "============================================"
echo "Current Configuration"
echo "============================================"
echo ""
echo "Container ${CTID} firewall rules:"
cat /etc/pve/firewall/${CTID}.fw
echo ""
echo "============================================"
echo "Firewall Status"
echo "============================================"
pve-firewall status
echo ""
echo "To view active rules:"
echo "  iptables -L -n -v | grep 25565"
echo ""
echo "To disable firewall for container ${CTID}:"
echo "  Edit /etc/pve/firewall/${CTID}.fw and set 'enable: 0'"
echo ""
echo "To test ports from external machine:"
echo "  telnet jee.bz 25565"
echo "  nc -zv jee.bz 25565"
