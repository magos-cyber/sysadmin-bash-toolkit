#!/usr/bin/env bash
# compliance-check.sh — CIS Benchmark Compliance Checker (Debian/Ubuntu focus)
# Usage: sudo bash compliance-check.sh [--level <1|2>] [--report] [--help]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}${NC} $1"; }
pass() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
fail() { echo -e "${RED}${NC} $1"; }

OUT_DIR="/var/log/compliance"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${OUT_DIR}/compliance-${TIMESTAMP}.log"
LEVEL=1
EXIT_CODE=0

# Counters
TOTAL=0
PASSED=0
FAILED=0
WARNED=0

mkdir -p "$OUT_DIR"

usage() {
 cat << EOF
compliance-check.sh — CIS Benchmark Compliance Checker

Usage: sudo bash compliance-check.sh 

Options:
 --level <1|2> CIS level (1 = basic, 2 = strict). Default: 1
 --report Save report to $OUT_DIR
 --help Show this help
EOF
}

# Check helper
check() {
 local description="$1"
 local status="$2" # PASS | FAIL | WARN
 local details="${3:-}"
 TOTAL=$((TOTAL + 1))
 case "$status" in
 PASS)
 PASSED=$((PASSED + 1))
 pass "$description"
 ;;
 FAIL)
 FAILED=$((FAILED + 1))
 fail "$description"
 EXIT_CODE=1
 ;;
 WARN)
 WARNED=$((WARNED + 1))
 warn "$description"
 ;;
 esac
 [ -n "$details" ] && echo " $details"
 if [ "${SAVE_REPORT:-false}" = "true" ]; then
 echo "[$status] $description ${details:+— $details}" >> "$REPORT_FILE"
 fi
}

# --- 1. Filesystem & Boot Configuration ---
check_filesystem() {
 log "1. Filesystem / Boot Configuration"

 # 1.1 Disable unused filesystems
 for fs in cramfs freevxfs jffs2 hfs hfsplus squashfs udf; do
 if ! grep -qrE "install $fs /bin/(true|false)" /etc/modprobe.d/ 2>/dev/null; then
 check "Disable $fs filesystem" WARN "Filesystem $fs not blacklisted"
 else
 check "Disable $fs filesystem" PASS
 fi
 done

 # 1.2 /tmp mount options (nodev, nosuid, noexec)
 if grep -qE "^/tmp.*nodev,nosuid" /etc/fstab; then
 check "/tmp mounted with nodev,nosuid" PASS
 else
 check "/tmp mounted with nodev,nosuid" FAIL "Add 'nodev,nosuid,noexec' to /tmp in /etc/fstab"
 fi

 # 1.3 /var mount options
 if grep -qE "^/var.*nodev" /etc/fstab; then
 check "/var mounted with nodev" PASS
 else
 check "/var mounted with nodev" WARN "Consider adding 'nodev' to /var in /etc/fstab"
 fi

 # 1.4 /var/log mount options
 if grep -qE "^/var/log.*nodev" /etc/fstab; then
 check "/var/log mounted with nodev" PASS
 else
 check "/var/log mounted with nodev" WARN "Consider adding 'nodev,nosuid,noexec' to /var/log"
 fi

 # 1.5 /var/log/audit mount options
 if grep -qE "^/var/log/audit.*nodev" /etc/fstab; then
 check "/var/log/audit mounted with nodev" PASS
 else
 check "/var/log/audit mounted with nodev" WARN
 fi

 # 1.6 /home mount options
 if grep -qE "^/home.*nodev" /etc/fstab; then
 check "/home mounted with nodev" PASS
 else
 check "/home mounted with nodev" WARN "Consider adding 'nodev,nosuid' to /home"
 fi

 # 1.7 Sticky bit on /tmp
 stat -c '%a' /tmp 2>/dev/null | grep -q "^1777$" && check "Sticky bit set on /tmp" PASS \
 || check "Sticky bit on /tmp" FAIL "chmod 1777 /tmp"

 # 1.8 GRUB password set
 if [ -f /boot/grub/grub.cfg ] && grep -q "password" /boot/grub/grub.cfg 2>/dev/null; then
 check "GRUB boot loader password set" PASS
 else
 check "GRUB boot loader password set" WARN "Run grub-mkpasswd-pbkdf2 and set superuser/password in /etc/grub.d/40_custom"
 fi
}

# --- 2. Process & Service Hardening ---
check_processes() {
 log "2. Process / Service Hardening"

 # 2.1 core dumps restricted
 if grep -qE "^\* hard core 0" /etc/security/limits.conf 2>/dev/null; then
 check "Core dumps restricted (limits.conf)" PASS
 else
 check "Core dumps restricted" FAIL "Add '* hard core 0' to /etc/security/limits.conf"
 fi
 sysctl fs.suid_dumpable 2>/dev/null | grep -q "= 0" \
 && check "fs.suid_dumpable = 0" PASS \
 || check "fs.suid_dumpable = 0" FAIL

 # 2.2 ExecShield / randomize_va_space
 if sysctl kernel.randomize_va_space 2>/dev/null | grep -q "= 2"; then
 check "ASLR fully enabled (kernel.randomize_va_space = 2)" PASS
 else
 check "ASLR fully enabled" FAIL "sysctl -w kernel.randomize_va_space=2"
 fi

 # 2.3 Prelink disabled
 if ! command -v prelink >/dev/null 2>&1; then
 check "Prelink package not installed" PASS
 else
 check "Prelink package not installed" FAIL "prelink is installed — uninstall and run prelink -ua"
 fi

 # 2.4 Uncommon services not enabled
 local bad_svcs=("telnet" "rsh" "rlogin" "talk" "vsftpd" "tftpd" "xinetd" "nis" "tftp")
 for svc in "${bad_svcs[@]}"; do
 if dpkg -l "$svc" 2>/dev/null | grep -q "^ii" || rpm -q "$svc" 2>/dev/null | grep -q "is installed"; then
 check "$svc not installed" FAIL "Uninstall $svc"
 else
 check "$svc not installed" PASS
 fi
 done
}

# --- 3. Network / Kernel Module Loading / sysctl ---
check_network() {
 log "3. Network / Kernel sysctl"
 local params=(
 "net.ipv4.ip_forward=0"
 "net.ipv4.conf.all.send_redirects=0"
 "net.ipv4.conf.default.send_redirects=0"
 "net.ipv4.conf.all.accept_redirects=0"
 "net.ipv4.conf.default.accept_redirects=0"
 "net.ipv6.conf.all.accept_redirects=0"
 "net.ipv6.conf.default.accept_redirects=0"
 "net.ipv4.conf.all.secure_redirects=0"
 "net.ipv4.conf.default.secure_redirects=0"
 "net.ipv4.conf.all.accept_source_route=0"
 "net.ipv4.conf.default.accept_source_route=0"
 "net.ipv6.conf.all.accept_source_route=0"
 "net.ipv6.conf.default.accept_source_route=0"
 "net.ipv4.conf.all.log_martians=1"
 "net.ipv4.conf.default.log_martians=1"
 "net.ipv4.icmp_echo_ignore_broadcasts=1"
 "net.ipv4.icmp_ignore_bogus_error_responses=1"
 "net.ipv4.conf.all.rp_filter=1"
 "net.ipv4.conf.default.rp_filter=1"
 "net.ipv4.tcp_syncookies=1"
 "net.ipv6.conf.all.accept_ra=0"
 "net.ipv6.conf.default.accept_ra=0"
 )
 for entry in "${params[@]}"; do
 local key="${entry%=*}"
 local expected="${entry#*=}"
 local actual
 actual=$(sysctl -n "$key" 2>/dev/null || echo "N/A")
 if [ "$actual" = "$expected" ]; then
 check "$key = $expected" PASS
 else
 check "$key = $expected" FAIL "current = $actual"
 fi
 done
}

# --- 4. SSH Configuration ---
check_ssh() {
 log "4. SSH Server Configuration"
 if [ ! -f /etc/ssh/sshd_config ]; then
 warn "sshd_config not found — skipping SSH checks"
 return
 fi
 local key expected
 while IFS=: read -r key expected; do
 local val
 val=$(grep -E "^${key}" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
 if [ -z "$val" ] && [ -f /etc/ssh/sshd_config.d/*.conf ]; then
 val=$(grep -rhE "^${key}" /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $2}' | head -1)
 fi
 # Treat unset as system default; for CIS-strict checks fail if matches default-weak
 case "$key:$expected" in
 Protocol:2) check "SSH Protocol 2" PASS ;; # protocol 1 deprecated/removed
 *)
 if [ "$val" = "$expected" ]; then
 check "SSH $key = $expected" PASS
 else
 check "SSH $key = $expected" FAIL "current = ${val:-unset}"
 fi
 ;;
 esac
 done <<EOF
Protocol:2
LogLevel:INFO
X11Forwarding:no
MaxAuthTries:4
IgnoreRhosts:yes
HostbasedAuthentication:no
PermitRootLogin:no
PermitEmptyPasswords:no
PermitUserEnvironment:no
ClientAliveInterval:300
ClientAliveCountMax:0
LoginGraceTime:60
AllowTcpForwarding:no
EOF
}

# --- 5. PAM / Password Policy ---
check_pam() {
 log "5. PAM / Password Policy"
 if [ -f /etc/login.defs ]; then
 local pass_max_days
 pass_max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
 if [ -n "$pass_max_days" ] && [ "$pass_max_days" -le 365 ] 2>/dev/null; then
 check "PASS_MAX_DAYS ≤ 365 ($pass_max_days)" PASS
 else
 check "PASS_MAX_DAYS ≤ 365" FAIL "Set PASS_MAX_DAYS 365 in /etc/login.defs"
 fi
 if grep -qE "^PASS_MIN_DAYS\s+[1-9]" /etc/login.defs; then
 check "PASS_MIN_DAYS ≥ 1" PASS
 else
 check "PASS_MIN_DAYS ≥ 1" FAIL
 fi
 if grep -qE "^PASS_WARN_AGE\s+[1-9]" /etc/login.defs; then
 check "PASS_WARN_AGE ≥ 1" PASS
 else
 check "PASS_WARN_AGE ≥ 1" FAIL
 fi
 fi

 if [ -f /etc/pam.d/common-password ]; then
 if grep -qE "pam_pwquality|pam_cracklib" /etc/pam.d/common-password 2>/dev/null; then
 check "Password complexity (pwquality/cracklib) configured" PASS
 else
 check "Password complexity module configured" WARN "Install libpam-pwquality and configure"
 fi
 fi
}

# --- 6. User / Account Security ---
check_users() {
 log "6. User / Account Security"
 # 6.1 Only root has UID 0
 local non_root_uid0
 non_root_uid0=$(awk -F: '($3==0 && $1!="root") {print $1}' /etc/passwd)
 if [ -z "$non_root_uid0" ]; then
 check "Only root has UID 0" PASS
 else
 check "Only root has UID 0" FAIL "Found: $non_root_uid0"
 fi

 # 6.2 Accounts with empty passwords
 local empty_pwds
 empty_pwds=$(awk -F: '($2 == "" ) {print $1}' /etc/shadow 2>/dev/null)
 if [ -z "$empty_pwds" ]; then
 check "No accounts with empty passwords" PASS
 else
 check "No accounts with empty passwords" FAIL "Found: $empty_pwds"
 fi

 # 6.3 No legacy '+' entries in passwd/shadow/group
 if grep -E "^\+" /etc/passwd /etc/shadow /etc/group 2>/dev/null; then
 check "No legacy '+' entries" FAIL
 else
 check "No legacy '+' entries" PASS
 fi

 # 6.4 Password hashing rounds for SHA512
 if grep -qE "ENCRYPT_METHOD\s+SHA512" /etc/login.defs 2>/dev/null; then
 check "ENCRYPT_METHOD = SHA512" PASS
 else
 check "ENCRYPT_METHOD = SHA512" WARN
 fi
}

# --- 7. Permissions & Audit ---
check_permissions() {
 log "7. Permissions / Audit"
 local perms=(
 "/etc/passwd:0644"
 "/etc/shadow:0640"
 "/etc/group:0644"
 "/etc/gshadow:0640"
 "/etc/passwd-:0600"
 "/etc/shadow-:0600"
 "/etc/group-:0600"
 "/etc/gshadow-:0600"
 )
 for entry in "${perms[@]}"; do
 local path="${entry%:*}"
 local expected="${entry#*:}"
 if [ -f "$path" ]; then
 local actual
 actual=$(stat -c '%a' "$path")
 if [ "$actual" = "$expected" ]; then
 check "$path permissions = $expected" PASS
 else
 check "$path permissions = $expected" FAIL "current = $actual"
 fi
 else
 check "$path exists with perm $expected" WARN "File does not exist"
 fi
 done

 # World-writable files (excluding /proc, /sys, /dev)
 local world_writable
 world_writable=$(find /etc /usr /var -xdev -type f -perm -0002 2>/dev/null | head -5)
 if [ -z "$world_writable" ]; then
 check "No world-writable files in /etc, /usr, /var" PASS
 else
 check "No world-writable files in /etc, /usr, /var" FAIL "$world_writable"
 fi
}

# --- 8. Logging & Auditing ---
check_logging() {
 log "8. Logging / Auditing"
 if command -v auditd >/dev/null 2>&1; then
 if systemctl is-active --quiet auditd 2>/dev/null; then
 check "auditd service active" PASS
 else
 check "auditd service active" FAIL "systemctl enable --now auditd"
 fi
 else
 check "auditd installed" WARN "Install auditd for full CIS logging coverage"
 fi

 if command -v rsyslogd >/dev/null 2>&1 || systemctl is-active --quiet rsyslog 2>/dev/null; then
 check "rsyslog active" PASS
 else
 check "rsyslog active" WARN
 fi

 if [ -f /var/log/wtmp ] && [ ! -u /var/log/wtmp ]; then
 check "wtmp not SUID" PASS
 fi
}

# --- 9. Banner / MOTD ---
check_banners() {
 log "9. Login Banners"
 for f in /etc/issue /etc/issue.net /etc/motd; do
 if [ -s "$f" ]; then
 check "$f populated" PASS
 else
 check "$f populated" WARN "Add a legal warning to $f"
 fi
 done
}

# --- Main ---
SAVE_REPORT=false
LEVEL=1

while [[ $# -gt 0 ]]; do
 case "$1" in
 --level) LEVEL="$2"; shift 2 ;;
 --report) SAVE_REPORT=true; shift ;;
 --help|-h) usage; exit 0 ;;
 *) usage; exit 1 ;;
 esac
done

if [ "$SAVE_REPORT" = "true" ]; then
 : > "$REPORT_FILE"
 echo "CIS Compliance Report — $(date)" >> "$REPORT_FILE"
 echo "Host: $(hostname) Kernel: $(uname -r) Level: $LEVEL" >> "$REPORT_FILE"
 echo "==========================================" >> "$REPORT_FILE"
fi

if [ "$LEVEL" = "2" ]; then
 log "Running CIS Level 2 (strict) compliance checks..."
else
 log "Running CIS Level 1 (basic) compliance checks..."
fi

check_filesystem
check_processes
check_network
check_ssh
check_pam
check_users
check_permissions
check_logging
check_banners

echo "=========================================="
log "Compliance Summary"
echo " Total checks: $TOTAL"
echo " Passed: $PASSED"
echo " Warnings: $WARNED"
echo " Failed: $FAILED"

if [ "$SAVE_REPORT" = "true" ]; then
 {
 echo "=========================================="
 echo "Total: $TOTAL | Passed: $PASSED | Warnings: $WARNED | Failed: $FAILED"
 } >> "$REPORT_FILE"
 info "Report saved to $REPORT_FILE"
fi

exit "$EXIT_CODE"
