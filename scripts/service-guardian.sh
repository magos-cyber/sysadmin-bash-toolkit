#!/bin/bash
# Service Guardian
# Monitors critical services and restarts them if they fail

SERVICES="nginx postgresql redis docker"
LOG="/var/log/service_guardian.log"

check_service() {
    if ! systemctl is-active --quiet "$1"; then
        echo "[$(date)] Service $1 is down, restarting..." | tee -a "$LOG"
        systemctl restart "$1"
        sleep 2
        if systemctl is-active --quiet "$1"; then
            echo "[$(date)] $1 restarted successfully" | tee -a "$LOG"
        else
            echo "[$(date)] FAILED to restart $1" | tee -a "$LOG"
        fi
    fi
}

echo "[$(date)] Service Guardian started" | tee -a "$LOG"

while true; do
    for svc in $SERVICES; do
        check_service "$svc"
    done
    sleep 30
done
