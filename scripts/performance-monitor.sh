#!/bin/bash
# Performance Monitor
# Real-time system performance dashboard

while true; do
    clear
    echo "=== System Performance ==="
    echo "Date: $(date)"
    echo ""
    
    echo "--- CPU ---"
    top -bn1 | grep "Cpu(s)" | awk '{print "Usage: " $2 "%"}'
    
    echo ""
    echo "--- Memory ---"
    free -h | grep -E "Mem|Swap"
    
    echo ""
    echo "--- Disk ---"
    df -h | grep -E "Filesystem|/dev/"
    
    echo ""
    echo "--- Network ---"
    ip -s link | grep -E "RX|TX" | head -4
    
    echo ""
    echo "--- Top Processes ---"
    ps aux --sort=-%mem | head -6
    
    sleep 5
done
