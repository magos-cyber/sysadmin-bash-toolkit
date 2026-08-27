#!/usr/bin/env bash
# hass-backup.sh — Backup Home Assistant configuration
# Usage: sudo bash hass-backup.sh [--snapshot name]
# Cron: 0 3 * * * /path/to/hass-backup.sh >> /var/log/homelab/hass-backup.log 2>&1

set -euo pipefail

HA_CONFIG="/homeassistant/config"  # adjust if using different path
BACKUP_DIR="/mnt/backup/homeassistant"
RETENTION_DAYS=30
SNAPSHOT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --snapshot) SNAPSHOT_NAME="$2"; shift 2 ;;
        --config) HA_CONFIG="$2"; shift 2 ;;
        --dir) BACKUP_DIR="$2"; shift 2 ;;
        --retention) RETENTION_DAYS="$2"; shift 2 ;;
        *) warn "Unknown arg: $1"; shift ;;
    esac
done

log() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [INFO] $1"; }
warn() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [WARN] $1"; }
error() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [ERROR] $1"; exit 1; }

mkdir -p "$BACKUP_DIR"

if [[ -z "$SNAPSHOT_NAME" ]]; then
    SNAPSHOT_NAME="ha-backup-$(date +%Y%m%d-%H%M%S)"
fi

ARCHIVE="$BACKUP_DIR/${SNAPSHOT_NAME}.tar.gz"

log "Starting Home Assistant backup -> $ARCHIVE"
if tar -czf "$ARCHIVE" -C "$HA_CONFIG" . 2>/dev/null; then
    log "Backup created ($(du -h "$ARCHIVE" | cut -f1))"
else
    warn "Backup finished with warnings"
fi

# Rotation
DELETED=$(find "$BACKUP_DIR" -name "ha-backup-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete -print 2>/dev/null | wc -l)
log "Rotated (deleted > ${RETENTION_DAYS}d): $DELETED"

# Integrity check
if gzip -t "$ARCHIVE" 2>/dev/null; then log "Integrity OK"; else warn "Integrity FAILED for $ARCHIVE"; fi

log "Backup complete."