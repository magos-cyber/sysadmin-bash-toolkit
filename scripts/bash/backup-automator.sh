#!/usr/bin/env bash
# backup-automator.sh — Generic file/folder backup with rotation + Telegram notify
# Usage: sudo bash backup-automator.sh
# Cron: 30 3 * * * /path/to/backup-automator.sh >> /var/log/homelab/backup.log 2>&1

set -euo pipefail

# --- Config (override via env or edit here) ---
BACKUP_DIR="${BACKUP_DIR:-/mnt/backup/files}"
SRC_DIRS=("${SRC_DIRS[@]:-/etc /opt/stacks /home/admin/.config}")
RETENTION_DAYS="${RETENTION_DAYS:-14}"
PREFIX="homelab"
NOTIFY_TELEGRAM="${NOTIFY_TELEGRAM:-false}"
BOT_TOKEN="${BOT_TOKEN:-YOUR_BOT_TOKEN}"
CHAT_ID="${CHAT_ID:-YOUR_CHAT_ID}"

log() { echo "[$(date '+%Y-%m-%d %H:%M')] [INFO] $1"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M')] [WARN] $1"; }

mkdir -p "$BACKUP_DIR"

TS=$(date '+%Y%m%d-%H%M%S')
ARCHIVE="$BACKUP_DIR/${PREFIX}-${TS}.tar.gz"

log "Starting backup -> $ARCHIVE"
if tar -czf "$ARCHIVE" "${SRC_DIRS[@]}" 2>/dev/null; then
    log "Archive created ($(du -h "$ARCHIVE" | cut -f1))"
else
    warn "tar finished with warnings"
fi

# Rotation
DELETED=$(find "$BACKUP_DIR" -name "${PREFIX}-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete -print 2>/dev/null | wc -l)
log "Rotated (deleted > ${RETENTION_DAYS}d): $DELETED"

# Integrity check
if gzip -t "$ARCHIVE" 2>/dev/null; then log "Integrity OK"; else warn "Integrity FAILED for $ARCHIVE"; fi

if [[ "$NOTIFY_TELEGRAM" == true ]]; then
  SIZE=$(du -h "$ARCHIVE" | cut -f1)
  MSG="💾 <b>Backup done</b>%0AFile: $ARCHIVE%0ASize: $SIZE%0ARetention: ${RETENTION_DAYS}d"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" -d "text=${MSG}" -d "parse_mode=HTML" >/dev/null 2>&1
fi

log "Backup complete."
