#!/usr/bin/env bash
# performance-monitor.sh — Continuous performance monitoring with alerts
# Usage: sudo bash performance-monitor.sh [--interval SECONDS] [--duration HOURS] [--alert-threshold]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[MONITOR]${NC} $1"; }
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
alert() { echo -e "${RED}[ALERT]${NC} $1"; }

# Default values
INTERVAL=300  # 5 minutes
DURATION=0    # 0 means run indefinitely until stopped
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=4.0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --cpu-threshold)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        --memory-threshold)
            MEMORY_THRESHOLD="$2"
            shift 2
            ;;
        --disk-threshold)
            DISK_THRESHOLD="$2"
            shift 2
            ;;
        --load-threshold)
            LOAD_THRESHOLD="$2"
            shift 2
            ;;
        *)
            error "Unknown argument: $1"
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)"; fi

LOG_FILE="/var/log/performance-monitor-$(date +%Y%m%d-%H%M%S).log"
START_TIME=$(date +%s)
END_TIME=0

if [[ $DURATION -gt 0 ]]; then
    END_TIME=$((START_TIME + DURATION * 3600))
fi

log "Starting performance monitor..."
log "Interval: ${INTERVAL}s"
if [[ $DURATION -gt 0 ]]; then
    log "Duration: ${DURATION}h"
else
    log "Duration: Indefinite (press Ctrl+C to stop)"
fi
log "Thresholds - CPU: ${CPU_THRESHOLD}%, Memory: ${MEMORY_THRESHOLD}%, Disk: ${DISK_THRESHOLD}%, Load: ${LOAD_THRESHOLD}"
log "Log file: $LOG_FILE"

# Write header to log file
{
    echo "Performance Monitor Log - Started at $(date)"
    echo "Interval: ${INTERVAL}s"
    echo "Thresholds - CPU: ${CPU_THRESHOLD}%, Memory: ${MEMORY_THRESHOLD}%, Disk: ${DISK_THRESHOLD}%, Load: ${LOAD_THRESHOLD}"
    echo "================================================================================"
} > "$LOG_FILE"

# Trap Ctrl+C for graceful shutdown
trap 'log "Performance monitor stopped by user"; exit 0' INT

while true; do
    # Check if duration limit reached
    if [[ $END_TIME -gt 0 && $(date +%s) -ge $END_TIME ]]; then
        log "Monitoring duration reached. Stopping."
        break
    fi
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Collect metrics
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
    
    # Check for alerts
    ALERT_TRIGGERED=false
    
    # CPU check
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        alert "High CPU usage: ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
        ALERT_TRIGGERED=true
    fi
    
    # Memory check
    if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        alert "High memory usage: ${MEMORY_USAGE}% (threshold: ${MEMORY_THRESHOLD}%)"
        ALERT_TRIGGERED=true
    fi
    
    # Disk check
    if [[ $DISK_USAGE -gt $DISK_THRESHOLD ]]; then
        alert "High disk usage: ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
        ALERT_TRIGGERED=true
    fi
    
    # Load average check (1-minute load)
    if (( $(echo "$LOAD_AVERAGE > $LOAD_THRESHOLD" | bc -l) )); then
        alert "High load average: ${LOAD_AVERAGE} (threshold: ${LOAD_THRESHOLD})"
        ALERT_TRIGGERED=true
    fi
    
    # Log metrics
    {
        echo "[$TIMESTAMP] CPU: ${CPU_USAGE}% | Memory: ${MEMORY_USAGE}% | Disk: ${DISK_USAGE}% | Load: ${LOAD_AVERAGE}"
        if [[ $ALERT_TRIGGERED == true ]]; then
            echo "  *** ALERTS TRIGGERED ***"
        fi
    } >> "$LOG_FILE"
    
    # Also print to console (less frequent)
    if [[ $(( $(date +%s) % 300 )) -lt $INTERVAL ]]; then  # Print every 5 minutes to console
        info "[$TIMESTAMP] CPU: ${CPU_USAGE}% | Memory: ${MEMORY_USAGE}% | Disk: ${DISK_USAGE}% | Load: ${LOAD_AVERAGE}"
        if [[ $ALERT_TRIGGERED == true ]]; then
            warn "  *** ALERTS TRIGGERED ***"
        fi
    fi
    
    # Sleep until next interval
    sleep $INTERVAL
done

log "Performance monitor finished."
log "Final log saved to: $LOG_FILE"