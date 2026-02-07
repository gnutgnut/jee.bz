#!/bin/bash
# Weekly offsite backup to Google Drive
# Uploads the most recent local backup to gdrive:minecraft-backups/

BACKUP_DIR="/opt/minecraft/backups"
GDRIVE_DIR="gdrive:minecraft-backups"
LOG_FILE="/var/log/offsite-backup.log"

echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] Starting offsite backup" >> $LOG_FILE

# Find the most recent backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.tar.gz 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] ERROR: No backups found" >> $LOG_FILE
    exit 1
fi

BACKUP_NAME=$(basename "$LATEST_BACKUP")
echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] Uploading $BACKUP_NAME" >> $LOG_FILE

# Upload to Google Drive
rclone copy "$LATEST_BACKUP" "$GDRIVE_DIR/" --log-file=$LOG_FILE --log-level INFO

# Keep only last 4 weekly backups on Google Drive (1 month)
echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] Cleaning old offsite backups" >> $LOG_FILE
rclone lsf "$GDRIVE_DIR/" --files-only | sort -r | tail -n +5 | while read OLD_BACKUP; do
    echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] Deleting old backup: $OLD_BACKUP" >> $LOG_FILE
    rclone delete "$GDRIVE_DIR/$OLD_BACKUP"
done

echo "[$(date -u '+%Y-%m-%d %H:%M UTC')] Offsite backup complete" >> $LOG_FILE
