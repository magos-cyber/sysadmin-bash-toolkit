#!/usr/bin/env bash
# hass-update.sh — Pull latest Home Assistant image and restart container
# Usage: sudo bash hass-update.sh

set -euo pipefail

log() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [INFO] $1"; }
warn() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [WARN] $1"; }
error() { echo -e "[$(date '+%Y-%m-%d %H:%M')] [ERROR] $1"; exit 1; }

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

CONFIG_DIR="/homeassistant/config"  # adjust if needed
COMPOSE_FILE="/homeassistant/docker-compose.yml"  # if you use compose

log "Pulling latest Home Assistant image..."
docker pull ghcr.io/homeassistant/home-assistant:stable

if [[ -f "$COMPOSE_FILE" ]]; then
    log "Restarting via docker compose..."
    (cd "$(dirname "$COMPOSE_FILE")" && docker compose up -d --remove-orphans homeassistant)
else
    log "Stopping and removing existing container..."
    docker stop homeassistant 2>/dev/null || true
    docker rm homeassistant 2>/dev/null || true
    log "Starting new container..."
    docker run -d \
        --name homeassistant \
        --restart unless-stopped \
        -v "$CONFIG_DIR":/config \
        -v /etc/localtime:/etc/localtime:ro \
        -e TZ=Europe/Athens \
        -p 8123:8123 \
        ghcr.io/homeassistant/home-assistant:stable
fi

log "Home Assistant updated successfully."