#!/bin/bash
# Log Manager
# Manages log rotation, archiving, and cleanup

LOG_DIRS="/var/log /var/log/nginx /var/log/mysql"
ARCHIVE_DIR="/var/log/archives"
RETENTION_DAYS=30

mkdir -p "$ARCHIVE_DIR"

echo "=== Log Manager ==="

# Archive old logs
for dir in $LOG_DIRS; do
    if [ -d "$dir" ]; then
        find "$dir" -name "*.log" -mtime +7 -exec gzip {} \;
        find "$dir" -name "*.gz" -exec mv {} "$ARCHIVE_DIR/" \;
    fi
done

# Cleanup old archives
find "$ARCHIVE_DIR" -name "*.gz" -mtime +$RETENTION_DAYS -delete

# Show disk usage
echo "Log disk usage:"
du -sh /var/log
du -sh "$ARCHIVE_DIR"

echo "Log management complete"
