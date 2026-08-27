#!/usr/bin/env bash
# security-scanner.sh — Automated security scanning (lynis-style checks)
# Usage: sudo bash security-scanner.sh [--quick] [--full]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}${NC} $1"; }
info() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; }
success() { echo -e "${GREEN}${NC} $1"; }

QUICK_MODE=false
FULL_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
 case $1 in
 --quick)
 QUICK_MODE=true
 shift
 ;;
 --full)
 FULL_MODE=true
 shift
 ;;
 *)
 error "Unknown argument: $1"
 ;;
 esac
done

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

SCAN_DATE=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="/var/log/security-scan"
REPORT_FILE="${REPORT_DIR}/security-scan-${SCAN_DATE}.log"
HARDENING_FILE="${REPORT_DIR}/hardening-suggestions-${SCAN_DATE}.log"

mkdir -p "$REPORT_DIR"

{
 log "Starting security scan..."
 log "Date: $(date)"
 log "Mode: ${QUICK_MODE} && echo 'Quick' || ${FULL_MODE} && echo 'Full' || echo 'Standard'"
 log "Report will be saved to: $REPORT_FILE"
 
 # System Information
 log "=== SYSTEM INFORMATION ==="
 hostnamectl | grep -E "Static hostname|Operating System|Kernel" || true
 lsb_release -a 2>/dev/null || true
 
 # User and Group Checks
 log "=== USER AND GROUP CHECKS ==="
 # Check for users with UID 0
 echo "Users with UID 0 (root):"
 awk -F: '($3==0) {print $1}' /etc/passwd
 
 # Check for accounts with empty passwords
 echo "Accounts with empty passwords:"
 awk -F: '($2 == "" || $2 == "*") {print $1}' /etc/shadow 2>/dev/null || true
 
 # Check for duplicate UIDs
 echo "Duplicate UIDs:"
 cut -f3 -d":" /etc/passwd | sort -n | uniq -c | awk '$1>1 {print $2}'
 
 # Service Checks
 log "=== SERVICE CHECKS ==="
 echo "Listening services:"
 ss -tuln | grep LISTEN
 
 # Check for unnecessary services
 echo "Checking for potentially unnecessary services..."
 systemctl list-unit-files --type=service | grep enabled
 
 # Firewall Status
 log "=== FIREWALL STATUS ==="
 if command -v ufw >/dev/null; then
 echo "UFW Status:"
 ufw status verbose
 elif command -v firewall-cmd >/dev/null; then
 echo "FirewallD Status:"
 firewall-cmd --state
 firewall-cmd --list-all
 elif command -v iptables >/dev/null; then
 echo "IPTables Rules:"
 iptables -L -v -n
 else
 warn "No firewall management tool found"
 fi
 
 # SSH Configuration
 log "=== SSH CONFIGURATION ==="
 if [ -f /etc/ssh/sshd_config ]; then
 echo "SSH Configuration Issues:"
 grep -E "^(PermitRootLogin|PasswordAuthentication|PermitEmptyPasswords)" /etc/ssh/sshd_config | grep -vE "(PermitRootLogin prohibit-password|PasswordAuthentication no|PermitEmptyPasswords no)" || true
 fi
 
 # File Permissions
 log "=== FILE PERMISSIONS CHECK ==="
 echo "World-writable files in /etc:"
 find /etc -type f -perm -002 2>/dev/null | head -10
 
 echo "Setuid files:"
 find / -type f -perm -4000 2>/dev/null | grep -v "/proc/" | head -10
 
 # Update Check
 log "=== UPDATE STATUS ==="
 if command -v apt-get >/dev/null; then
 echo "Available updates:"
 apt-get upgrade --dry-run 2>/dev/null | grep "^Inst" || true
 echo "Security updates available:"
 apt-get upgrade --dry-run 2>/dev/null | grep "security" || true
 fi
 
 # Log Monitoring
 log "=== LOG MONITORING ==="
 echo "Failed login attempts (last 24h):"
 journalctl _SYSTEMD_UNIT=sshd.service --since "24 hours ago" | grep "Failed password" | wc -l || true
 
 # Generate hardening suggestions
 {
 echo "=== HARDENING SUGGESTIONS ==="
 echo "1. Consider disabling root SSH login if not already done"
 echo "2. Ensure SSH key-based authentication is enabled"
 echo "3. Regularly review listening services"
 echo "4. Keep system updated with security patches"
 echo "5. Monitor /var/log/auth.log for suspicious activity"
 echo "6. Consider implementing intrusion detection (fail2ban, auditd)"
 echo "7. Regularly backup critical configuration files"
 echo "8. Review file permissions on sensitive directories"
 } >> "$HARDENING_FILE"
 
 log "Security scan completed."
 log "Detailed report: $REPORT_FILE"
 log "Hardening suggestions: $HARDENING_FILE"
 
} 2>&1 | tee -a "$REPORT_FILE"

# Summary
echo
echo "=== SECURITY SCAN SUMMARY ==="
echo "Scan completed at: $(date)"
echo "Full report saved to: $REPORT_FILE"
if [ -s "$HARDENING_FILE" ]; then
 echo "Hardening suggestions available in: $HARDENING_FILE"
 echo "Number of suggestions: $(wc -l < "$HARDENING_FILE")"
fi

# Cleanup old reports (keep last 30 days)
find "$REPORT_DIR" -name "security-scan-*" -mtime +30 -delete 2>/dev/null || true
find "$REPORT_DIR" -name "hardening-suggestions-*" -mtime +30 -delete 2>/dev/null || true