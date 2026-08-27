#!/usr/bin/env bash
# kernel-hardening.sh — Comprehensive Kernel Security Hardening (Sysctl, Modules, GRUB, Limits)
# Usage: sudo bash kernel-hardening.sh [--apply] [--audit] [--rollback]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[KERNEL-HARDEN]${NC} $1"; }
info() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; exit 1; }

SYSCTL_CONF="/etc/sysctl.d/99-kernel-security.conf"
MODPROBE_CONF="/etc/modprobe.d/security-blacklist.conf"
BACKUP_DIR="/var/backups/kernel-hardening-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/kernel-hardening-$(date +%Y%m%d-%H%M%S).log"

if [[ $EUID -ne 0 ]]; then
 error "This script must be run as root (sudo)"
fi

# Audit Mode
audit_kernel() {
 log "Auditing current kernel hardening posture..."
 echo "=========================================="
 echo "1. Kernel Pointer Leaks & ASLR"
 echo "------------------------------------------"
 echo -n "kptr_restrict (should be >= 1): "
 sysctl kernel.kptr_restrict 2>/dev/null || cat /proc/sys/kernel/kptr_restrict
 echo -n "dmesg_restrict (should be == 1): "
 sysctl kernel.dmesg_restrict 2>/dev/null || cat /proc/sys/kernel/dmesg_restrict
 echo -n "Randomize VA space (ASLR, should be == 2): "
 sysctl kernel.randomize_va_space 2>/dev/null || cat /proc/sys/kernel/randomize_va_space

 echo -e "\n2. Network & Spoofing Protections"
 echo "------------------------------------------"
 echo -n "Reverse Path Filtering (rp_filter, should be 1): "
 sysctl net.ipv4.conf.all.rp_filter 2>/dev/null || echo "N/A"
 echo -n "TCP SYN Cookies: "
 sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo "N/A"
 echo -n "Accept Source Route: "
 sysctl net.ipv4.conf.all.accept_source_route 2>/dev/null || echo "N/A"
 echo -n "Accept Redirects: "
 sysctl net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "N/A"

 echo -e "\n3. Memory & Core Dumps"
 echo "------------------------------------------"
 echo -n "Protected Symlinks/Hardlinks: "
 sysctl fs.protected_symlinks 2>/dev/null || echo "N/A"
 sysctl fs.protected_hardlinks 2>/dev/null || echo "N/A"
 echo -n "Core Dump SUID protection: "
 sysctl fs.suid_dumpable 2>/dev/null || echo "N/A"

 echo -e "\n4. Filesystem & Kernel Modules Blacklist"
 echo "------------------------------------------"
 for mod in cramfs freevxfs jffs2 hfs hfsplus squashfs udf usb-storage bluetooth; do
 if lsmod | grep -q "^$mod "; then
 echo "Module $mod: LOADED (Warning: Recommended to blacklist if unused)"
 else
 echo "Module $mod: Not loaded"
 fi
 done
 echo "=========================================="
}

# Rollback Mode
rollback_hardening() {
 log "Rolling back kernel security hardening..."
 if [ -d "/var/backups" ]; then
 LATEST_BACKUP=$(ls -td /var/backups/kernel-hardening-* 2>/dev/null | head -1 || true)
 if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP/99-kernel-security.conf" ]; then
 cp "$LATEST_BACKUP/99-kernel-security.conf" "$SYSCTL_CONF"
 sysctl --system
 info "Restored sysctl configuration from $LATEST_BACKUP"
 else
 warn "No valid backup found to restore sysctl."
 fi
 if [ -f "$LATEST_BACKUP/security-blacklist.conf" ]; then
 cp "$LATEST_BACKUP/security-blacklist.conf" "$MODPROBE_CONF"
 info "Restored modprobe blacklist from $LATEST_BACKUP"
 fi
 else
 error "No backup directory found."
 fi
 info "Rollback completed."
}

# Apply Mode
apply_hardening() {
 mkdir -p "$BACKUP_DIR"
 log "Backing up existing configurations to $BACKUP_DIR..."
 [ -f "$SYSCTL_CONF" ] && cp "$SYSCTL_CONF" "$BACKUP_DIR/"
 [ -f "$MODPROBE_CONF" ] && cp "$MODPROBE_CONF" "$BACKUP_DIR/"

 log "Applying hardened sysctl parameters..."
 cat > "$SYSCTL_CONF" << 'EOF'
# ==========================================
# KERNEL SECURITY HARDENING PARAMETERS
# ==========================================

# --- 1. Memory Protection & ASLR ---
# Ensure Address Space Layout Randomization is fully enabled
kernel.randomize_va_space = 2

# Restrict kernel symbol addresses exposure (kptr_restrict)
# 0 = no restriction, 1 = restricted for unprivileged users, 2 = always hidden
kernel.kptr_restrict = 2

# Restrict access to kernel logs (dmesg) for unprivileged users
kernel.dmesg_restrict = 1

# Restrict ptrace scope to prevent process tampering/injection
# 0 = classic ptrace, 1 = restricted to parent, 2 = admin only, 3 = none
kernel.yama.ptrace_scope = 2

# Restrict kexec (loading another kernel)
kernel.kexec_load_disabled = 1

# Disable SysRq magic trigger (emergency reboot/dump keys) unless needed (can set to 1 for basic debug or 0 to disable)
kernel.sysrq = 0

# Prevent unintended core dumps for SUID programs
fs.suid_dumpable = 0

# --- 2. Filesystem & Symlink Protections ---
# Prevent following symlinks owned by different users in world-writable sticky dirs (/tmp)
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# --- 3. Network Stack & Spoofing Defenses ---
# IP Spoofing protection via Reverse Path Filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcasts (Smurf attack prevention)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing (prevent source routing bypass)
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore ICMP redirect messages (prevent man-in-the-middle routing tampering)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_dad = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Log packets with impossible addresses (Martian packets)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Enable TCP SYN Cookies for SYN flood attack mitigation
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Enable TCP timestamps slack/randomization
net.ipv4.tcp_timestamps = 1

# Disable IPv6 if not required (optional, but keep enabled with privacy extensions by default if needed)
# net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

 sysctl --system >/dev/null 2>&1
 info "Sysctl security parameters applied successfully."

 log "Blacklisting uncommon or risky filesystems and kernel modules..."
 cat > "$MODPROBE_CONF" << 'EOF'
# Disable uncommon and legacy filesystems to reduce kernel attack surface
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install usb-storage /bin/true
install firewire-core /bin/true
install bluetooth /bin/true
install btusb /bin/true
EOF
 info "Module blacklist configuration written."

 log "Checking GRUB configuration for security flags (audit/mitigations)..."
 if [ -f /etc/default/grub ]; then
 if ! grep -q "page_alloc.shuffle=1" /etc/default/grub; then
 warn "Consider adding kernel mitigations to GRUB_CMDLINE_LINUX (e.g., slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1)"
 fi
 fi

 info "Kernel security hardening successfully applied!"
 log "Backup stored in: $BACKUP_DIR"
}

# Main Dispatcher
case "${1:---apply}" in
 --apply)
 apply_hardening
 ;;
 --audit)
 audit_kernel
 ;;
 --rollback)
 rollback_hardening
 ;;
 *)
 echo "Usage: sudo bash kernel-hardening.sh [--apply | --audit | --rollback]"
 exit 1
 ;;
esac
