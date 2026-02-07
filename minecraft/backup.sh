#\!/bin/bash
# Minecraft World Backup Script
# Keeps last 7 daily backups

BACKUP_DIR="/opt/minecraft/backups"
WORLD_DIR="/opt/minecraft/world"
MAX_BACKUPS=7
DATE=$(date +%Y-%m-%d_%H%M)

# Notify server
RCON_PASS="${RCON_PASSWORD:-$(grep rcon.password /opt/minecraft/server.properties | cut -d= -f2)}"
/usr/local/bin/mcrcon -H 127.0.0.1 -P 25575 -p "$RCON_PASS" "say Starting backup..." 2>/dev/null

# Disable autosave during backup
/usr/local/bin/mcrcon -H 127.0.0.1 -P 25575 -p $RCON_PASS "save-off" 2>/dev/null
/usr/local/bin/mcrcon -H 127.0.0.1 -P 25575 -p $RCON_PASS "save-all" 2>/dev/null
sleep 5

# Create backup
tar -czf "${BACKUP_DIR}/world_${DATE}.tar.gz" -C /opt/minecraft world

# Re-enable autosave
/usr/local/bin/mcrcon -H 127.0.0.1 -P 25575 -p $RCON_PASS "save-on" 2>/dev/null
/usr/local/bin/mcrcon -H 127.0.0.1 -P 25575 -p $RCON_PASS "say Backup complete\!" 2>/dev/null

# Delete old backups (keep last MAX_BACKUPS)
cd "${BACKUP_DIR}"
ls -t world_*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm --

echo "Backup completed: world_${DATE}.tar.gz"
ls -lh "${BACKUP_DIR}"
