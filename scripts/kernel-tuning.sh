#!/bin/bash
# Kernel Tuning
# Applies performance and security kernel parameters

SYSCTL_CONF="/etc/sysctl.d/99-custom.conf"

echo "=== Kernel Tuning ==="

cat > "$SYSCTL_CONF" << 'EOF'
# Security
kernel.randomize_va_space = 2
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fastopen = 3
EOF

sysctl -p "$SYSCTL_CONF"
echo "Kernel parameters applied"
