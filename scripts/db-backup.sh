#!/bin/bash
# Database Backup Utility
# Supports PostgreSQL, MySQL/MariaDB

set -euo pipefail

DB_TYPE="${1:-postgres}"
DB_NAME="${2:-all}"
BACKUP_DIR="/var/backups/db/$(date +%Y-%m-%d)"
RETENTION=7

mkdir -p "$BACKUP_DIR"

echo "=== Database Backup ==="

case "$DB_TYPE" in
    postgres)
        if [ "$DB_NAME" = "all" ]; then
            sudo -u postgres pg_dumpall | gzip > "$BACKUP_DIR/all.sql.gz"
        else
            sudo -u postgres pg_dump "$DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}.sql.gz"
        fi
        ;;
    mysql)
        if [ "$DB_NAME" = "all" ]; then
            mysqldump -u root -p --all-databases | gzip > "$BACKUP_DIR/all.sql.gz"
        else
            mysqldump -u root -p "$DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}.sql.gz"
        fi
        ;;
    *)
        echo "Unsupported DB: $DB_TYPE"
        exit 1
        ;;
esac

echo "Backup saved to $BACKUP_DIR"

# Cleanup old
find "$BACKUP_DIR/.." -name "*.sql.gz" -mtime +"$RETENTION" -delete
echo "Cleaned up backups older than $RETENTION days"
