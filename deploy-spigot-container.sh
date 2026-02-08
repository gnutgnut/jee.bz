#!/bin/bash
# Proxmox LXC Container Deployment Script for Minecraft Spigot Server
# Run this script ON the Proxmox host
# Mirrors container 100 (Fabric) but with Spigot instead

set -e

# Configuration
CTID=103  # Container ID
HOSTNAME="minecraft-spigot"
PASSWORD="ChangeMe123!"  # Change this!
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

# Resources (same as Fabric container)
CORES=12
MEMORY=24576  # 24GB in MB
SWAP=4096
DISK_SIZE=100 # 100GB

# Network
BRIDGE="vmbr0"
IP="dhcp"

echo "============================================"
echo "Minecraft Spigot Server Container Deployment"
echo "============================================"
echo ""
echo "Configuration:"
echo "  CTID: ${CTID}"
echo "  Hostname: ${HOSTNAME}"
echo "  Cores: ${CORES}"
echo "  RAM: ${MEMORY}MB"
echo "  Disk: ${DISK_SIZE}GB"
echo "  Template: ${TEMPLATE}"
echo ""

# Check if container already exists
if pct status ${CTID} >/dev/null 2>&1; then
    echo "ERROR: Container ${CTID} already exists!"
    pct config ${CTID}
    echo ""
    echo "Please either:"
    echo "  1. Destroy existing container: pct stop ${CTID} && pct destroy ${CTID}"
    echo "  2. Use a different CTID (edit this script)"
    exit 1
fi

# Validate storage pool exists
if ! pvesm status | grep -q "^${STORAGE}"; then
    echo "ERROR: Storage pool '${STORAGE}' not found!"
    pvesm status
    exit 1
fi

read -p "Press Enter to continue or Ctrl+C to abort..."

# Check if template exists, download if needed
if ! pveam list ${STORAGE%:*} | grep -q "debian-12-standard"; then
    echo "Downloading Debian 12 template..."
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst
    TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
fi

# Create the container
echo "Creating LXC container..."
pct create ${CTID} ${TEMPLATE} \
    --hostname ${HOSTNAME} \
    --password ${PASSWORD} \
    --cores ${CORES} \
    --memory ${MEMORY} \
    --swap ${SWAP} \
    --rootfs ${STORAGE}:${DISK_SIZE} \
    --net0 name=eth0,bridge=${BRIDGE},ip=${IP},firewall=0 \
    --mp0 /mnt/shared,mp=/mnt/shared \
    --features nesting=1 \
    --unprivileged 0 \
    --onboot 0 \
    --start 0

echo "Container ${CTID} created successfully!"
echo ""
echo "IMPORTANT: onboot is OFF by default."
echo "Only one MC container should auto-start. Use switch-mc.sh to swap."
echo ""
echo "Starting container..."
pct start ${CTID}

echo "Waiting for container to be ready..."
sleep 10

for i in {1..30}; do
    if pct exec ${CTID} -- echo "ready" >/dev/null 2>&1; then
        echo "Container is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Container failed to start properly"
        exit 1
    fi
    sleep 1
done

echo "Updating container and installing base packages..."
pct exec ${CTID} -- bash -c "apt-get update && apt-get upgrade -y"
pct exec ${CTID} -- bash -c "apt-get install -y curl wget git nano htop screen sudo ufw"

echo ""
echo "============================================"
echo "Container deployment complete!"
echo "============================================"
echo ""
echo "Container ID: ${CTID}"
echo "Hostname: ${HOSTNAME}"
echo ""
echo "Next steps:"
echo "  1. Copy spigot-setup.sh to the container:"
echo "     cat spigot-setup.sh | pct exec ${CTID} -- tee /root/spigot-setup.sh > /dev/null"
echo "  2. Run: pct exec ${CTID} -- bash /root/spigot-setup.sh"
echo "  3. Set up static DHCP binding for this container's MAC"
echo "  4. Update iptables rules (switch-mc.sh handles this)"
echo ""
echo "To get container MAC:"
echo "  pct config ${CTID} | grep net0"
