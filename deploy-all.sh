#!/bin/bash
# Complete Deployment Script - Automates entire setup
# Run this script FROM YOUR LOCAL MACHINE

set -e

PROXMOX_HOST="jee.bz"
PROXMOX_USER="root"
CTID=100

echo "============================================"
echo "Minecraft Fabric Server - Complete Deployment"
echo "============================================"
echo ""
echo "This script will:"
echo "  1. Copy deployment scripts to Proxmox"
echo "  2. Create and configure LXC container"
echo "  3. Configure Proxmox firewall rules"
echo "  4. Install Minecraft Fabric server"
echo "  5. Set up web management panel (optional)"
echo "  6. Configure automated backups"
echo ""
echo "Target: ${PROXMOX_USER}@${PROXMOX_HOST}"
echo "Container ID: ${CTID}"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

echo ""
echo "[1/6] Copying deployment scripts to Proxmox..."
scp deploy-container.sh minecraft-setup.sh pterodactyl-setup.sh backup-setup.sh configure-firewall.sh \
    ${PROXMOX_USER}@${PROXMOX_HOST}:/root/

echo ""
echo "[2/6] Creating LXC container..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "bash /root/deploy-container.sh"

echo ""
echo "[3/6] Configuring Proxmox firewall..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "bash /root/configure-firewall.sh"

echo ""
echo "[4/6] Installing Minecraft Fabric server..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct push ${CTID} /root/minecraft-setup.sh /root/minecraft-setup.sh"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct exec ${CTID} -- bash /root/minecraft-setup.sh"

echo ""
read -p "Install MCSManager web panel? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[5/6] Installing web management panel..."
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct push ${CTID} /root/pterodactyl-setup.sh /root/pterodactyl-setup.sh"
    ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct exec ${CTID} -- bash /root/pterodactyl-setup.sh"
else
    echo "[5/6] Skipping web panel installation"
fi

echo ""
echo "[6/6] Setting up automated backups..."
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct push ${CTID} /root/backup-setup.sh /root/backup-setup.sh"
ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct exec ${CTID} -- bash /root/backup-setup.sh"

echo ""
echo "============================================"
echo "Deployment Complete!"
echo "============================================"
echo ""
echo "Your Minecraft Fabric server is ready!"
echo ""
echo "Connection details:"
echo "  Server IP: ${PROXMOX_HOST}"
echo "  Port: 25565"
echo "  Connect in Minecraft: ${PROXMOX_HOST}:25565"
echo ""

# Get container IP
CONTAINER_IP=$(ssh ${PROXMOX_USER}@${PROXMOX_HOST} "pct exec ${CTID} -- hostname -I | awk '{print \$1}'")

if [ -n "${CONTAINER_IP}" ]; then
    echo "Container IP: ${CONTAINER_IP}"
    echo ""
fi

echo "Web management:"
echo "  MCSManager: http://${PROXMOX_HOST}:24444"
echo "  Default login: admin / 123456"
echo "  CHANGE PASSWORD IMMEDIATELY!"
echo ""
echo "Management commands (SSH into Proxmox first):"
echo "  Enter container: pct enter ${CTID}"
echo "  Start server: systemctl start minecraft"
echo "  Stop server: systemctl stop minecraft"
echo "  View logs: journalctl -u minecraft -f"
echo ""
echo "Next steps:"
echo "  1. Configure server settings in /opt/minecraft/server.properties"
echo "  2. Change RCON password"
echo "  3. Add yourself as operator: /op YOUR_USERNAME"
echo "  4. Install additional mods in /opt/minecraft/mods/"
echo "  5. Configure whitelist if desired"
echo ""
echo "Documentation: See README.md for complete guide"
