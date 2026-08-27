#!/usr/bin/env bash
# security-hardening.sh — Apply baseline fail2ban + UFW rules for a homelab node
# Usage: sudo bash security-hardening.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

log "Applying baseline security hardening..."

# --- UFW ---
log "Configuring UFW firewall..."
ufw reset >/dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh comment 'SSH access'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
# Allow local network (adjust as needed)
# ufw allow from 192.168.1.0/24 to any port 22 comment 'LAN SSH'
ufw --force enable
log "UFW enabled and configured."

# --- Fail2Ban ---
log "Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 86400

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
bantime = 604800  ; 1 week
findtime = 86400
maxretry = 5
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2Ban enabled and restarted."

# --- Additional sysctl hardening ---
log "Applying sysctl hardening..."
cat > /etc/sysctl.d/99-homelab-security.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP redirects (unless we are router)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 0
EOF

sysctl --system >/dev/null 2>&1
log "Sysctl hardening applied."

log "=========================================="
log "Security hardening complete!"
log "=========================================="
log "Next steps:"
log "  • Consider setting up SSH key‑only auth (disable PasswordAuthentication)"
log "  • Install and configure logwatch or similar for daily reports"
log "  • Monitor /var/log/fail2ban.log for blocked IPs"