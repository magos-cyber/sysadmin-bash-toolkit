#!/usr/bin/env python3
"""
disk-monitor.py — Disk monitoring with Telegram alerts
Usage: python3 disk-monitor.py
Cron: */30 * * * * /usr/bin/python3 /path/to/disk-monitor.py >> /var/log/homelab/disk-monitor.log 2>&1
"""

import shutil
import os
import json
import urllib.request
import urllib.parse
from datetime import datetime
from pathlib import Path

# Configuration
CONFIG = {
    "telegram": {
        "enabled": False,
        "bot_token": "YOUR_BOT_TOKEN",
        "chat_id": "YOUR_CHAT_ID"
    },
    "thresholds": {
        "warning": 80,  # Warning at 80%
        "critical": 90  # Critical at 90%
    },
    "paths": ["/", "/home", "/var", "/opt"],
    "log_file": "/var/log/homelab/disk-monitor.log",
    "state_file": "/var/lib/homelab/disk-monitor-state.json"
}


def load_config():
    """Load config from file if exists"""
    config_path = Path("/etc/homelab/disk-monitor.json")
    if config_path.exists():
        with open(config_path) as f:
            return {**CONFIG, **json.load(f)}
    return CONFIG


def get_disk_usage(path: str) -> dict:
    """Get disk usage for a given path"""
    try:
        usage = shutil.disk_usage(path)
        return {
            "path": path,
            "total_gb": round(usage.total / (1024**3), 2),
            "used_gb": round(usage.used / (1024**3), 2),
            "free_gb": round(usage.free / (1024**3), 2),
            "percent": round((usage.used / usage.total) * 100, 1)
        }
    except Exception as e:
        return {"path": path, "error": str(e)}


def send_telegram_alert(message: str, config: dict):
    """Send alert via Telegram bot"""
    if not config["telegram"]["enabled"]:
        return

    url = f"https://api.telegram.org/bot{config['telegram']['bot_token']}/sendMessage"
    data = urllib.parse.urlencode({
        "chat_id": config["telegram"]["chat_id"],
        "text": message,
        "parse_mode": "HTML"
    }).encode()

    try:
        req = urllib.request.Request(url, data=data)
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"[ERROR] Telegram alert failed: {e}")


def load_state(state_file: str) -> dict:
    """Load previous state to avoid duplicate alerts"""
    try:
        with open(state_file) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state: dict, state_file: str):
    """Save current state"""
    os.makedirs(os.path.dirname(state_file), exist_ok=True)
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)


def main():
    config = load_config()
    
    # Ensure log directory exists
    os.makedirs(os.path.dirname(config["log_file"]), exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    alerts = []
    status_lines = []
    state = load_state(config["state_file"])
    new_state = {}

    for path in config["paths"]:
        if not os.path.exists(path):
            continue
            
        usage = get_disk_usage(path)
        
        if "error" in usage:
            status_lines.append(f"[WARNING] {path}: Error - {usage['error']}")
            continue

        # Determine status
        if usage["percent"] >= config["thresholds"]["critical"]:
            status = "[RED] CRITICAL"
            alert_key = f"{path}_critical"
            if state.get(alert_key) != "critical":
                alerts.append(
                    f"[RED] <b>CRITICAL</b> - {path}\n"
                    f"   {usage['percent']}% in use\n"
                    f"   {usage['free_gb']}GB free of {usage['total_gb']}GB"
                )
                new_state[alert_key] = "critical"
            else:
                new_state[alert_key] = "critical"
                
        elif usage["percent"] >= config["thresholds"]["warning"]:
            status = "[YELLOW] WARNING"
            alert_key = f"{path}_warning"
            if state.get(alert_key) != "warning":
                alerts.append(
                    f"[YELLOW] <b>WARNING</b> - {path}\n"
                    f"   {usage['percent']}% in use\n"
                    f"   {usage['free_gb']}GB free of {usage['total_gb']}GB"
                )
                new_state[alert_key] = "warning"
            else:
                new_state[alert_key] = "warning"
        else:
            status = "[GREEN] OK"
            # Clear state if recovered
            new_state[f"{path}_critical"] = "ok"
            new_state[f"{path}_warning"] = "ok"

        status_lines.append(
            f"{status} {path}: {usage['percent']}% "
            f"({usage['used_gb']}/{usage['total_gb']}GB)"
        )

    # Build report
    report = f"[CHART] <b>Disk Monitor</b> - {timestamp}\n\n"
    report += "\n".join(status_lines)

    # Log report
    print(report.replace("<b>", "").replace("</b>", ""))
    
    # Write to log
    with open(config["log_file"], "a") as f:
        f.write(f"\n{'='*50}\n{report}\n")

    # Send alerts if any
    if alerts:
        alert_msg = f"[ALERT] <b>Disk Alert!</b>\n\n" + "\n\n".join(alerts)
        send_telegram_alert(alert_msg, config)
        print(f"\n[OUTBOX] Sent {len(alerts)} alerts")

    # Save state
    save_state(new_state, config["state_file"])


if __name__ == "__main__":
    main()