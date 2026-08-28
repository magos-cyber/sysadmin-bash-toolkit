#!/bin/bash
# SSH Hardening Script
# Applies security best practices to SSH configuration

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "=== SSH Hardening ==="

# Backup original config
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

# Apply hardening
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD_CONFIG"

echo "SSH configuration updated."
echo "Review changes and restart SSH: systemctl restart sshd"
