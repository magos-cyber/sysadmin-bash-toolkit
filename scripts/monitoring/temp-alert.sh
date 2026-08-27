#!/usr/bin/env bash
# temp-alert.sh — CPU temperature alerts via Telegram
# Usage: bash temp-alert.sh
# Cron: */15 * * * * /path/to/temp-alert.sh >> /var/log/homelab/temp-alert.log 2>&1

set -euo pipefail

# Configuration
TEMP_THRESHOLD=70 # Critical threshold in °C
BOT_TOKEN="YOUR_BOT_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
STATE_FILE="/var/lib/homelab/temp-alert-state"

# Read CPU temperature (lm-sensors or thermal zone)
get_cpu_temp() {
 # Try sensors (lm-sensors)
 if command -v sensors &> /dev/null; then
 sensors | grep 'Core' | awk '{print $3}' | sed 's/+//;s/°C//' | sort -rn | head -1
 return
 fi
 
 # Fallback: thermal zone
 if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
 local temp
 temp=$(cat /sys/class/thermal/thermal_zone0/temp)
 echo "scale=1; $temp / 1000" | bc
 return
 fi
 
 echo "0"
}

# Send Telegram alert
send_alert() {
 local temp=$1
 local message
 message=" <b>High CPU Temperature!</b>
 
Temperature: <b>${temp}°C</b>
Threshold: ${TEMP_THRESHOLD}°C
Server: $(hostname)
Time: $(date '+%Y-%m-%d %H:%M:%S')

 Check your cooling system!"
 
 curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
 -d "chat_id=${CHAT_ID}" \
 -d "text=${message}" \
 -d "parse_mode=HTML" > /dev/null 2>&1
}

# Send recovery notification
send_recovery() {
 local temp=$1
 local message
 message=" <b>Temperature Normal</b>
 
Temperature: <b>${temp}°C</b>
Server: $(hostname)
Time: $(date '+%Y-%m-%d %H:%M:%S')

Temperature is back to normal levels."
 
 curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
 -d "chat_id=${CHAT_ID}" \
 -d "text=${message}" \
 -d "parse_mode=HTML" > /dev/null 2>&1
}

# Main logic
main() {
 # Create state directory
 mkdir -p /var/lib/homelab
 
 # Read temperature
 TEMP=$(get_cpu_temp)
 
 # Check if it's a number
 if ! [[ "$TEMP" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
 echo " Could not read temperature"
 exit 1
 fi
 
 # Compare with threshold
 PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "normal")
 
 if (( $(echo "$TEMP >= $TEMP_THRESHOLD" | bc -l) )); then
 echo "[$(date '+%Y-%m-%d %H:%M')] HIGH: ${TEMP}°C"
 
 # Send alert only if previously normal
 if [[ "$PREV_STATE" == "normal" ]]; then
 send_alert "$TEMP"
 echo "alert" > "$STATE_FILE"
 fi
 else
 echo "[$(date '+%Y-%m-%d %H:%M')] OK: ${TEMP}°C"
 
 # Recovery notification
 if [[ "$PREV_STATE" == "alert" ]]; then
 send_recovery "$TEMP"
 echo "normal" > "$STATE_FILE"
 fi
 fi
}

main "$@"