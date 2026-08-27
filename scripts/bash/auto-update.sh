#!/usr/bin/env bash
# auto-update.sh — Auto-update Docker containers & system packages
# Usage: sudo bash auto-update.sh [--include-system]
# Cron: 0 4 * * * /path/to/auto-update.sh >> /var/log/homelab/auto-update.log 2>&1

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M')]${NC} $1"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M')]${NC} $1"; }
info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M')]${NC} $1"; }

# Create log directory
mkdir -p /var/log/homelab

INCLUDE_SYSTEM=false
for arg in "$@"; do
    case $arg in
        --include-system) INCLUDE_SYSTEM=true ;;
    esac
done

log "=========================================="
log "Starting auto-update..."
log "=========================================="

# 1. Update Docker images
log "Checking for new Docker images..."

COMPOSE_DIRS=(
    "/opt/stacks/media"
    "/opt/stacks/monitoring"
    "/opt/stacks/network"
    "/opt/stacks/utils"
)

UPDATED=0
FAILED=0

for dir in "${COMPOSE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        info "Processing: $dir"
        cd "$dir"
        
        # Pull new images
        if docker compose pull 2>/dev/null; then
            docker compose up -d --remove-orphans
            ((UPDATED++)) || true
            log "  [OK] Updated: $dir"
        else
            ((FAILED++)) || true
            warn "  [FAIL] Failed: $dir"
        fi
    fi
done

# 2. Cleanup old images
log "Cleaning up old Docker images..."
docker image prune -af --filter "until=168h" 2>/dev/null || true

# 3. System update (optional)
if [[ "$INCLUDE_SYSTEM" == true ]]; then
    log "Updating system..."
    apt-get update
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean
fi

# 4. Check for reboot
if [[ -f /var/run/reboot-required ]]; then
    warn "Reboot required! Run: sudo reboot"
fi

# 5. Health check
log "Health check services..."
SERVICES_OK=0
SERVICES_FAIL=0

for dir in "${COMPOSE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        cd "$dir"
        UNHEALTHY=$(docker compose ps --format json 2>/dev/null | grep -c "unhealthy" || true)
        if [[ "$UNHEALTHY" -gt 0 ]]; then
            warn "  [FAIL] $dir: $UNHEALTHY unhealthy containers"
            ((SERVICES_FAIL++)) || true
        else
            ((SERVICES_OK++)) || true
        fi
    fi
done

log "=========================================="
log "Auto-update complete!"
log "=========================================="
log "Results:"
log "  • Updated stacks: $UPDATED"
log "  • Failed: $FAILED"
log "  • Healthy services: $SERVICES_OK"
log "  • Unhealthy: $SERVICES_FAIL"
log ""
log "Log: /var/log/homelab/auto-update.log"