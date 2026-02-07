#!/bin/bash
# Port Testing and Verification Script
# Run this to verify all ports are accessible

PROXMOX_HOST="proxmox.cbmcra.website"
CONTAINER_IP=""  # Will be auto-detected or set manually

echo "============================================"
echo "Port Accessibility Check"
echo "============================================"
echo ""

# Try to detect container IP
if command -v pct &> /dev/null; then
    echo "Detecting container IP..."
    CONTAINER_IP=$(pct exec 100 -- hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$CONTAINER_IP" ]; then
        echo "Container IP: $CONTAINER_IP"
    fi
fi

echo ""
echo "Testing external accessibility..."
echo ""

# Test Minecraft port
echo -n "Minecraft (25565): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/25565" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

# Test RCON port
echo -n "RCON (25575): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/25575" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

# Test MCSManager Web
echo -n "MCSManager Web (24444): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/24444" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

# Test MCSManager Daemon
echo -n "MCSManager Daemon (23333): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/23333" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

# Test SSH
echo -n "SSH (22): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/22" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

# Test Proxmox Web
echo -n "Proxmox Web (8006): "
if timeout 2 bash -c "echo '' > /dev/tcp/${PROXMOX_HOST}/8006" 2>/dev/null; then
    echo "✓ OPEN"
else
    echo "✗ CLOSED or FILTERED"
fi

echo ""
echo "============================================"
echo "Firewall Status (if run on Proxmox host)"
echo "============================================"

if command -v pve-firewall &> /dev/null; then
    echo ""
    pve-firewall status
    echo ""
    echo "Container 100 firewall rules:"
    if [ -f /etc/pve/firewall/100.fw ]; then
        grep -E "^IN|^OUT" /etc/pve/firewall/100.fw
    else
        echo "No firewall rules found for container 100"
    fi
else
    echo "Not running on Proxmox host - skipping firewall status"
fi

echo ""
echo "============================================"
echo "Active Connections (if run in container)"
echo "============================================"

if [ -f /opt/minecraft/logs/latest.log ]; then
    echo ""
    echo "Listening ports:"
    ss -tlnp 2>/dev/null | grep -E "25565|25575|24444|23333" || echo "No services listening"
fi

echo ""
echo "To test from external machine:"
echo "  telnet ${PROXMOX_HOST} 25565"
echo "  nc -zv ${PROXMOX_HOST} 25565"
echo "  nmap -p 25565,25575,24444 ${PROXMOX_HOST}"
