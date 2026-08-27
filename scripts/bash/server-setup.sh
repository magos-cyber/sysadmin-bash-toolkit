#!/usr/bin/env bash
# server-setup.sh — Initial setup for new Debian/Ubuntu server
# Usage: sudo bash server-setup.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; exit 1; }

# Check root
if [[ $EUID -ne 0 ]]; then
 error "This script must be run as root (sudo)"
fi

log "Starting server setup..."

# 1. System update
log "Updating system..."
apt-get update && apt-get upgrade -y

# 2. Install basic packages
log "Installing basic packages..."
apt-get install -y \
 curl \
 wget \
 git \
 vim \
 htop \
 iotop \
 net-tools \
 unzip \
 software-properties-common \
 apt-transport-https \
 ca-certificates \
 gnupg \
 lsb-release \
 fail2ban \
 ufw \
 unattended-upgrades \
 logrotate

# 3. Set timezone
log "Setting timezone to Europe/Athens..."
timedatectl set-timezone Europe/Athens

# 4. Set hostname
read -rp "Enter hostname for the server (e.g. homelab-node1): " HOSTNAME
hostnamectl set-hostname "$HOSTNAME"
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
log "Hostname set: $HOSTNAME"

# 5. Create non-root user
read -rp "Enter username for new user (e.g. admin): " USERNAME
if id "$USERNAME" &>/dev/null; then
 warn "User $USERNAME already exists, skipping..."
else
 adduser --gecos "" "$USERNAME"
 usermod -aG sudo "$USERNAME"
 usermod -aG docker "$USERNAME" 2>/dev/null || true
 log "User $USERNAME created and added to sudo group"
fi

# 6. SSH hardening
log "SSH hardening..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl restart sshd
log "SSH hardening complete (root login disabled)"

# 7. Configure UFW firewall
log "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
log "UFW firewall enabled"

# 8. Configure fail2ban
log "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'

bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
EOF
systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2ban enabled"

# 9. Automatic security updates
log "Enabling automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
 "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 10. Configure logrotate
log "Configuring logrotate..."
cat > /etc/logrotate.d/homelab-custom << 'EOF'
/var/log/homelab/*.log {
 daily
 missingok
 rotate 14
 compress
 delaycompress
 notifempty
 create 0640 root adm
}
EOF

log "=========================================="
log "Setup completed successfully!"
log "=========================================="
log "Important notes:"
log " • SSH: Key-based auth only (no password)"
log " • Root login: Disabled"
log " • Firewall: UFW active"
log " • Fail2ban: SSH brute-force protection"
log " • Auto-updates: Security patches automatically"
log ""
log "Next steps:"
log " 1. Upload your public key to the new user: ~/.ssh/authorized_keys"
log " 2. Run docker-install.sh"
log " 3. Configure monitoring"