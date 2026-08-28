#!/bin/bash
# Incremental Backup using rsync with hardlinks
# Space-efficient daily backups

set -euo pipefail

SOURCE="${1:?Usage: $0 <source> <dest>}"
DEST="${2:?Usage: $0 <source> <dest>}"
KEEP="${3:-14}"

SNAP_DIR="$DEST/snapshots"
DATE=$(date +%Y-%m-%d_%H%M%S)
LATEST="$DEST/latest"

mkdir -p "$SNAP_DIR"

# First backup or incremental
if [ -d "$LATEST" ]; then
    rsync -aH --delete --link-dest="$LATEST" "$SOURCE/" "$SNAP_DIR/$DATE/"
else
    rsync -aH "$SOURCE/" "$SNAP_DIR/$DATE/"
fi

# Update latest symlink
rm -f "$LATEST"
ln -s "$SNAP_DIR/$DATE" "$LATEST"

# Rotate old snapshots
find "$SNAP_DIR" -maxdepth 1 -type d -mtime +"$KEEP" -exec rm -rf {} +

echo "Backup complete: $SNAP_DIR/$DATE"
