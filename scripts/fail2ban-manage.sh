#!/bin/bash
# Fail2Ban Management Script
# Manage jails, bans, and configuration

set -euo pipefail

case "${1:-help}" in
    status)
        echo "=== Fail2Ban Status ==="
        fail2ban-client status
        ;;
    jails)
        echo "=== Active Jails ==="
        fail2ban-client status | grep "Jail list" | sed 's/.*Jail list://' | tr ',' '\n' | while read jail; do
            jail=$(echo "$jail" | xargs)
            [ -n "$jail" ] && echo "  - $jail"
        done
        ;;
    ban)
        JAIL="${2:?Usage: $0 ban <jail> <ip>}"
        IP="${3:?Usage: $0 ban <jail> <ip>}"
        fail2ban-client set "$JAIL" banip "$IP"
        echo "Banned $IP in jail $JAIL"
        ;;
    unban)
        IP="${2:?Usage: $0 unban <ip>}"
        fail2ban-client unban "$IP"
        echo "Unbanned $IP"
        ;;
    logs)
        echo "=== Recent Fail2Ban Activity ==="
        journalctl -u fail2ban --since "1 hour ago" --no-pager | tail -20
        ;;
    *)
        echo "Usage: $0 {status|jails|ban|unban|logs}"
        ;;
esac
