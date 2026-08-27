#!/usr/bin/env bash
# log-forensics.sh — Log Analysis & Forensics Tool for Incident Response
# Usage: sudo bash log-forensics.sh [--analyze] [--timeline] [--ioc] [--report] [--help]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${BLUE}[FORENSICS]${NC} $1"; }
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Default log paths
AUTH_LOG="/var/log/auth.log"
SYSLOG="/var/log/syslog"
KERN_LOG="/var/log/kern.log"
DAEMON_LOG="/var/log/daemon.log"
NGINX_ACCESS="/var/log/nginx/access.log"
NGINX_ERROR="/var/log/nginx/error.log"
FAIL2BAN_LOG="/var/log/fail2ban.log"

OUT_DIR="/var/log/forensics"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${OUT_DIR}/forensics-report-${TIMESTAMP}.log"

mkdir -p "$OUT_DIR"

# Helper: which logs exist on this distro
detect_logs() {
    # On RHEL/CentOS, auth log is /var/log/secure
    if [ ! -f "$AUTH_LOG" ] && [ -f /var/log/secure ]; then
        AUTH_LOG="/var/log/secure"
    fi
    if [ ! -f "$SYSLOG" ] && [ -f /var/log/messages ]; then
        SYSLOG="/var/log/messages"
    fi
}

# Analyze authentication and SSH events
analyze_auth() {
    log "Analyzing authentication and SSH events..."
    echo "=========================================="
    echo "1. Failed SSH logins (last 100)"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "Failed password|Invalid user" "$AUTH_LOG" | tail -n 100 || true
    else
        warn "Auth log not found: $AUTH_LOG"
    fi

    echo -e "\n2. Successful logins"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "Accepted (password|publickey) for" "$AUTH_LOG" | tail -n 50 || true
    fi

    echo -e "\n3. SSH root login attempts"
    if [ -f "$AUTH_LOG" ]; then
        grep -i "root" "$AUTH_LOG" | grep -i "fail\|invalid" | tail -n 30 || true
    fi

    echo -e "\n4. Sudo usage by non-admin users"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "sudo:" "$AUTH_LOG" | tail -n 30 || true
    fi

    echo -e "\n5. Account creation/modification"
    if [ -f "$AUTH_LOG" ]; then
        grep -iE "new user|user added|user modified|passwd changed" "$AUTH_LOG" | tail -n 30 || true
    fi

    echo -e "\n6. Top 20 source IPs (failed logins)"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "Failed password" "$AUTH_LOG" | \
            grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -rn | head -20 || true
    fi

    echo -e "\n7. Top 20 usernames targeted"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "Failed password for" "$AUTH_LOG" | \
            grep -oE "for [^ ]+" | sort | uniq -c | sort -rn | head -20 || true
    fi
    echo "=========================================="
}

# Build a chronological incident timeline
build_timeline() {
    log "Building event timeline..."
    echo "=========================================="
    echo "Timeline of notable events (auth, sudo, service starts, segfaults):"
    for logfile in "$AUTH_LOG" "$SYSLOG" "$KERN_LOG" "$DAEMON_LOG"; do
        [ -f "$logfile" ] || continue
        grep -iE "accepted|fail|error|segfault|panic|service started|service failed" "$logfile" 2>/dev/null | \
            tail -n 50 || true
    done | sort -k1,2
    echo "=========================================="
}

# Indicator-of-Compromise extraction
extract_ioc() {
    log "Extracting Indicators of Compromise (IOCs)..."
    echo "=========================================="
    echo "1. Suspicious IPs (high failure count, possible brute force)"
    if [ -f "$AUTH_LOG" ]; then
        grep -E "Failed password" "$AUTH_LOG" | \
            grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -rn | head -20 || true
    fi

    echo -e "\n2. IP blacklist (current banned IPs via fail2ban)"
    if [ -f "$FAIL2BAN_LOG" ] && command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status 2>/dev/null | head -20 || true
    fi

    echo -e "\n3. Outbound connections (currently established, top 20 by count)"
    ss -ntu 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20 || true

    echo -e "\n4. Recently modified system files (last 7 days, /etc & /usr/local)"
    find /etc /usr/local -type f -mtime -7 2>/dev/null | head -30 || true

    echo -e "\n5. SUID binaries added (compare against dpkg if available)"
    find / -perm -4000 -type f 2>/dev/null | head -30 || true

    echo -e "\n6. Cron job changes (last 7 days)"
    find /etc/cron* /var/spool/cron -type f -mtime -7 2>/dev/null | head -20 || true

    echo -e "\n7. SSH keys added in user accounts (last 7 days)"
    find /home /root -name "authorized_keys" -mtime -7 2>/dev/null | head -10 || true
    echo "=========================================="
}

# Service health
analyze_services() {
    log "Analyzing system service health..."
    echo "=========================================="
    if [ -f "$SYSLOG" ]; then
        echo "1. Service start/failures (last 50)"
        grep -iE "Started|Stopped|Failed|systemd" "$SYSLOG" 2>/dev/null | tail -50 || true
    fi
    echo -e "\n2. Kernel panic / OOM events"
    if [ -f "$KERN_LOG" ]; then
        grep -iE "panic|out of memory|segfault|hard reset" "$KERN_LOG" 2>/dev/null | tail -30 || true
    fi
    echo -e "\n3. nginx HTTP status code summary (top 25)"
    if [ -f "$NGINX_ACCESS" ]; then
        awk '{print $9}' "$NGINX_ACCESS" 2>/dev/null | sort | uniq -c | sort -rn | head -25 || true
    fi
    echo -e "\n4. nginx top requested URLs"
    if [ -f "$NGINX_ACCESS" ]; then
        awk '{print $7}' "$NGINX_ACCESS" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || true
    fi
    echo "=========================================="
}

# Full report (all of the above) to file
full_report() {
    detect_logs
    log "Generating full forensics report → $REPORT_FILE"
    {
        echo "FORENSICS REPORT — $(date)"
        echo "Host: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime)"
        echo "=========================================="
        analyze_auth
        analyze_services
        build_timeline
        extract_ioc
    } > "$REPORT_FILE" 2>&1
    info "Full report saved to $REPORT_FILE"
}

# Show usage
usage() {
    cat << EOF
log-forensics.sh — Log Analysis & Forensics Tool for Incident Response

Usage: sudo bash log-forensics.sh [OPTION]

Options:
  --analyze      Analyze authentication and SSH events
  --timeline     Build a chronological event timeline
  --ioc          Extract Indicators of Compromise
  --report       Generate a full forensics report to /var/log/forensics
  --help         Show this help message

Examples:
  sudo bash log-forensics.sh --analyze
  sudo bash log-forensics.sh --report
EOF
}

# Main dispatcher
case "${1:---help}" in
    --analyze)
        detect_logs
        analyze_auth
        ;;
    --timeline)
        detect_logs
        build_timeline
        ;;
    --ioc)
        detect_logs
        extract_ioc
        ;;
    --report)
        full_report
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
