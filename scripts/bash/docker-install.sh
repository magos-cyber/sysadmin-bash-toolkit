#!/usr/bin/env bash
# docker-install.sh — Install Docker & Docker Compose on Debian/Ubuntu
# Usage: sudo bash docker-install.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}${NC} $1"; }
warn() { echo -e "${YELLOW}${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then
 error "This script must be run as root (sudo)"
fi

log "Starting Docker installation..."

# 1. Remove old versions
log "Removing old packages..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2. Install dependencies
log "Installing dependencies..."
apt-get update
apt-get install -y \
 ca-certificates \
 curl \
 gnupg \
 lsb-release

# 3. Add Docker GPG key
log "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Add Docker repository
log "Adding Docker repository..."
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
 $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker
log "Installing Docker Engine..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Enable and start Docker
log "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# 7. Verify installation
log "Verifying installation..."
docker --version
docker compose version

# 8. Add user to docker group
if [[ -n "${SUDO_USER:-}" ]]; then
 usermod -aG docker "$SUDO_USER"
 log "User $SUDO_USER added to docker group"
fi

# 9. Configure Docker daemon
log "Configuring Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
 "log-driver": "json-file",
 "log-opts": {
 "max-size": "10m",
 "max-file": "3"
 },
 "storage-driver": "overlay2",
 "live-restore": true,
 "default-address-pools": [
 {
 "base": "172.17.0.0/16",
 "size": 24
 }
 ]
}
EOF

systemctl restart docker

# 10. Docker cleanup cron job
log "Adding automated cleanup cron job..."
cat > /etc/cron.weekly/docker-cleanup << 'EOF'
#!/bin/bash
# Weekly Docker cleanup
docker system prune -f --volumes
docker image prune -af
EOF
chmod +x /etc/cron.weekly/docker-cleanup

log "=========================================="
log "Docker installed successfully!"
log "=========================================="
log "Version: $(docker --version)"
log "Compose: $(docker compose version)"
log ""
log "Settings:"
log " • Logging: json-file (max 10MB, 3 files)"
log " • Storage: overlay2"
log " • Live restore: enabled"
log " • Weekly cleanup: enabled"
log ""
log "Useful commands:"
log " docker ps # Running containers"
log " docker compose up -d # Start stack"
log " docker compose logs -f # View logs"
log " docker system df # Disk usage"