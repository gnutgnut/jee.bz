#!/bin/bash
# Proxmox LXC Container Deployment Script for Minecraft Fabric Server
# Run this script ON the Proxmox host

set -e

# Configuration
CTID=100  # Container ID - change if this ID is already in use
HOSTNAME="minecraft-fabric"
PASSWORD="ChangeMe123!"  # Change this!
STORAGE="local-lvm"  # Change to your storage pool name
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"  # Debian 12 template

# Resources
CORES=8
MEMORY=16384  # 16GB in MB
SWAP=4096     # 4GB swap
DISK_SIZE=100 # 100GB

# Network
BRIDGE="vmbr0"
IP="dhcp"  # Change to static IP if needed, e.g., "192.168.1.100/24"
GATEWAY=""  # Set if using static IP

echo "============================================"
echo "Minecraft Fabric Server Container Deployment"
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
    echo ""
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
    echo ""
    echo "Available storage pools:"
    pvesm status
    echo ""
    echo "Please edit this script and set STORAGE to a valid pool."
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
    --net0 name=eth0,bridge=${BRIDGE},ip=${IP},firewall=1 \
    --features nesting=1 \
    --unprivileged 0 \
    --onboot 1 \
    --start 0

echo "Container ${CTID} created successfully!"
echo ""
echo "Starting container..."
pct start ${CTID}

echo "Waiting for container to be ready..."
sleep 10

# Wait for container to be fully running
echo "Verifying container is running..."
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
echo "Root password: ${PASSWORD}"
echo ""
echo "Next steps:"
echo "  1. Copy minecraft-setup.sh to the container"
echo "  2. Run: pct enter ${CTID}"
echo "  3. Execute: bash /root/minecraft-setup.sh"
echo ""
echo "To enter container: pct enter ${CTID}"
echo "To stop container: pct stop ${CTID}"
echo "To start container: pct start ${CTID}"
