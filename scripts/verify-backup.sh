#!/bin/bash
# Backup Verification Script
# Tests backup integrity

set -euo pipefail

BACKUP_FILE="${1:?Usage: $0 <backup_file>}"

echo "=== Backup Verification ==="

# Check file exists and is not empty
if [ ! -s "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file is empty or missing"
    exit 1
fi

# Check file type
file_type=$(file "$BACKUP_FILE")

case "$BACKUP_FILE" in
    *.tar.gz|*.tgz)
        if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
            echo "ERROR: Corrupt tar.gz archive"
            exit 1
        fi
        echo "OK: Valid tar.gz archive"
        ;;
    *.sql.gz)
        if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
            echo "ERROR: Corrupt gzip file"
            exit 1
        fi
        echo "OK: Valid gzipped SQL dump"
        ;;
    *.gz)
        if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
            echo "ERROR: Corrupt gzip file"
            exit 1
        fi
        echo "OK: Valid gzip file"
        ;;
    *)
        echo "WARN: Unknown backup format, manual check needed"
        ;;
esac

# Check size
size=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Size: $size"
echo "Verification complete"
