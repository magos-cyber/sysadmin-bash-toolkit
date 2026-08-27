#!/usr/bin/env bash
# kernel-update.sh — Safe kernel update with backup and rollback capability
# Usage: sudo bash kernel-update.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

CURRENT_KERNEL=$(uname -r)
BACKUP_DIR="/boot/backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/kernel-update-$(date +%Y%m%d-%H%M%S).log"

log "Starting safe kernel update process..."
log "Current kernel: $CURRENT_KERNEL"
log "Backup directory: $BACKUP_DIR"
log "Log file: $LOG_FILE"

{
 # Create backup directory
 log "Creating backup directory..."
 mkdir -p "$BACKUP_DIR"
 
 # Backup current kernel and initrd
 log "Backing up current kernel and initrd..."
 cp /boot/vmlinuz-"$CURRENT_KERNEL" "$BACKUP_DIR/"
 cp /boot/initrd.img-"$CURRENT_KERNEL" "$BACKUP_DIR/" || true
 cp /boot/System.map-"$CURRENT_KERNEL" "$BACKUP_DIR/" || true
 cp /boot/config-"$CURRENT_KERNEL" "$BACKUP_DIR/" || true
 
 # Update package list
 log "Updating package lists..."
 apt-get update
 
 # Upgrade kernel packages
 log "Upgrading kernel packages..."
 apt-get install -y linux-image-generic linux-headers-generic
 
 # Get new kernel version
 NEW_KERNEL=$(ls /boot/vmlinuz-* | grep -v backup | sort -V | tail -1 | sed 's|/boot/vmlinuz-||')
 log "New kernel installed: $NEW_KERNEL"
 
 # Update GRUB
 log "Updating GRUB configuration..."
 update-grub
 
 log "Kernel update completed successfully!"
 log "Please reboot to use the new kernel: $NEW_KERNEL"
 log "To rollback, restore from $BACKUP_DIR and run update-grub"
 
} 2>&1 | tee -a "$LOG_FILE"

log "Kernel update process finished. Check $LOG_FILE for details."