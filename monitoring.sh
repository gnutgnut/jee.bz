#!/bin/bash
# Minecraft Server Monitoring Script
# Run inside the container to check server health

MINECRAFT_DIR="/opt/minecraft"
LOG_FILE="${MINECRAFT_DIR}/logs/latest.log"

echo "============================================"
echo "Minecraft Server Status"
echo "============================================"
echo ""

# Check if service is running
echo "Service Status:"
systemctl status minecraft --no-pager | grep -E "Active:|Main PID:|Memory:|CPU:"
echo ""

# Check process
echo "Java Process:"
ps aux | grep -E "java.*fabric-server" | grep -v grep || echo "  Not running"
echo ""

# Check ports
echo "Network Ports:"
echo "  Minecraft (25565):"
ss -tlnp | grep 25565 || echo "    Not listening"
echo "  RCON (25575):"
ss -tlnp | grep 25575 || echo "    Not listening"
echo ""

# System resources
echo "System Resources:"
echo "  RAM Usage:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "  CPU Load:"
uptime
echo ""
echo "  Disk Usage:"
df -h ${MINECRAFT_DIR} | tail -1
echo ""

# Check recent errors in logs
if [ -f "${LOG_FILE}" ]; then
    echo "Recent Log Entries (last 10 lines):"
    tail -n 10 ${LOG_FILE}
    echo ""

    echo "Recent Errors/Warnings:"
    grep -iE "error|warn|exception" ${LOG_FILE} | tail -5 || echo "  No recent errors found"
else
    echo "Log file not found: ${LOG_FILE}"
fi

echo ""
echo "Backups:"
if [ -d "/var/backups/minecraft" ]; then
    echo "  Latest backup:"
    ls -lht /var/backups/minecraft/*.tar.gz 2>/dev/null | head -1 || echo "    No backups found"
    echo ""
    echo "  Total backups: $(ls /var/backups/minecraft/*.tar.gz 2>/dev/null | wc -l)"
    echo "  Backup size: $(du -sh /var/backups/minecraft 2>/dev/null | cut -f1)"
else
    echo "  Backup directory not found"
fi

echo ""
echo "============================================"
echo "Quick Commands:"
echo "============================================"
echo "  Restart server:     systemctl restart minecraft"
echo "  View live logs:     journalctl -u minecraft -f"
echo "  Enter console:      (not available in systemd mode)"
echo "  Manual backup:      /usr/local/bin/backup-minecraft-world.sh"
echo "  Check players:      (use RCON or web panel)"
