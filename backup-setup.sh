#!/bin/bash
# Minecraft Backup Automation Setup
# Creates both Proxmox container snapshots and world data backups

set -e

MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/var/backups/minecraft"
CONTAINER_ID="100"  # Change to match your container ID
RETENTION_DAYS=7

echo "============================================"
echo "Minecraft Backup Automation Setup"
echo "============================================"

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Create world backup script (runs INSIDE container)
cat > /usr/local/bin/backup-minecraft-world.sh << 'INNEREOF'
#!/bin/bash
# Backup Minecraft world data

MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/var/backups/minecraft"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/minecraft-world-${TIMESTAMP}.tar.gz"
RETENTION_DAYS=7

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

echo "[$(date)] Starting Minecraft world backup..."

# Send save-off command to server via RCON (optional, requires rcon-cli)
# rcon-cli save-off
# rcon-cli save-all

# Backup world data
cd ${MINECRAFT_DIR}
tar -czf ${BACKUP_FILE} \
    world/ \
    world_nether/ \
    world_the_end/ \
    server.properties \
    ops.json \
    whitelist.json \
    banned-players.json \
    banned-ips.json \
    2>/dev/null || true

# Send save-on command
# rcon-cli save-on

# Remove old backups
find ${BACKUP_DIR} -name "minecraft-world-*.tar.gz" -mtime +${RETENTION_DAYS} -delete

BACKUP_SIZE=$(du -h ${BACKUP_FILE} | cut -f1)
echo "[$(date)] Backup complete: ${BACKUP_FILE} (${BACKUP_SIZE})"
INNEREOF

chmod +x /usr/local/bin/backup-minecraft-world.sh

# Create cron job for daily backups at 3 AM
echo "Setting up daily backup cron job..."
(crontab -l 2>/dev/null | grep -v backup-minecraft-world; echo "0 3 * * * /usr/local/bin/backup-minecraft-world.sh >> /var/log/minecraft-backup.log 2>&1") | crontab -

# Create Proxmox snapshot script (runs ON PROXMOX HOST)
cat > /root/backup-minecraft-container.sh << 'EOF'
#!/bin/bash
# Proxmox Container Snapshot Script
# Run this ON THE PROXMOX HOST

CTID=100  # Change to your container ID
SNAPSHOT_NAME="autobackup-$(date +%Y%m%d-%H%M%S)"
RETENTION_COUNT=7  # Keep last 7 snapshots

echo "[$(date)] Creating snapshot for container ${CTID}..."

# Create snapshot
vzdump ${CTID} --mode snapshot --storage local --compress zstd --remove 0

# Alternative: Use pct snapshot for quick snapshots
# pct snapshot ${CTID} ${SNAPSHOT_NAME}

# Clean up old snapshots (keep last RETENTION_COUNT)
# pct listsnapshot ${CTID} | tail -n +$((RETENTION_COUNT + 2)) | awk '{print $1}' | while read snap; do
#     echo "Removing old snapshot: ${snap}"
#     pct delsnapshot ${CTID} ${snap}
# done

echo "[$(date)] Snapshot complete!"
EOF

chmod +x /root/backup-minecraft-container.sh

# Create restore documentation
cat > ${BACKUP_DIR}/RESTORE.md << 'EOF'
# Minecraft Backup Restoration Guide

## World Data Restore (from tar.gz backup)

1. Stop the Minecraft server:
   ```bash
   systemctl stop minecraft
   ```

2. Backup current world (just in case):
   ```bash
   cd /opt/minecraft
   mv world world.old
   mv world_nether world_nether.old
   mv world_the_end world_the_end.old
   ```

3. Extract backup:
   ```bash
   cd /opt/minecraft
   tar -xzf /var/backups/minecraft/minecraft-world-TIMESTAMP.tar.gz
   ```

4. Fix permissions:
   ```bash
   chown -R minecraft:minecraft /opt/minecraft
   ```

5. Start server:
   ```bash
   systemctl start minecraft
   ```

## Container Snapshot Restore (Proxmox)

### Option 1: Restore from vzdump backup
```bash
# List available backups
ls -lh /var/lib/vz/dump/

# Restore (will overwrite container!)
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-TIMESTAMP.tar.zst

# Start container
pct start 100
```

### Option 2: Restore from pct snapshot
```bash
# List snapshots
pct listsnapshot 100

# Rollback to snapshot
pct rollback 100 SNAPSHOT_NAME

# Start container
pct start 100
```

## Testing Backups

Always test your backups regularly! Create a test restore on a different container ID to verify backup integrity.
EOF

echo ""
echo "============================================"
echo "Backup Setup Complete!"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Backup directory: ${BACKUP_DIR}"
echo "  Retention: ${RETENTION_DAYS} days"
echo "  Schedule: Daily at 3:00 AM"
echo ""
echo "Scripts created:"
echo "  World backup (container): /usr/local/bin/backup-minecraft-world.sh"
echo "  Snapshot (Proxmox host): /root/backup-minecraft-container.sh"
echo ""
echo "Manual backup commands:"
echo "  World: /usr/local/bin/backup-minecraft-world.sh"
echo "  Container: (On Proxmox) /root/backup-minecraft-container.sh"
echo ""
echo "Logs:"
echo "  tail -f /var/log/minecraft-backup.log"
echo ""
echo "Restore guide:"
echo "  cat ${BACKUP_DIR}/RESTORE.md"
echo ""
echo "To set up Proxmox host snapshots:"
echo "  1. Copy /root/backup-minecraft-container.sh to Proxmox host"
echo "  2. Add to Proxmox host crontab: 0 2 * * * /root/backup-minecraft-container.sh"
