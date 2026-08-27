# Sysadmin Bash Toolkit

Sysadmin Bash toolkit — server hardening, monitoring, backup automation, log management, and daily ops scripts. All scripts are production-ready with proper error handling and logging.

## Structure

```
sysadmin-bash-toolkit/
+-- scripts/
| +-- bash/
| | +-- server-setup.sh # Initial server hardening
| | +-- docker-install.sh # Install Docker & Compose
| | +-- auto-update.sh # Auto-update Docker stacks
| | +-- vpn-setup.sh # WireGuard VPN server
| | +-- backup-automator.sh # Rotating backups
| | +-- security-hardening.sh # UFW + Fail2Ban + sysctl
| | +-- hass-backup.sh # Home Assistant backup
| | +-- hass-update.sh # Home Assistant update
| | +-- kernel-update.sh # Safe kernel update with backup/rollback
| | +-- security-scanner.sh # Automated security scanning (lynis-style)
| | +-- performance-monitor.sh # Continuous performance monitoring with alerts
| | +-- kernel-hardening.sh # Comprehensive kernel security hardening (sysctl, modules, GRUB)
| | +-- container-security.sh # Docker/Podman security scanning & hardening audit
| | +-- log-forensics.sh # Log analysis & forensics for incident response
| | `-- compliance-check.sh # CIS benchmark compliance checker
| +-- monitoring/
| | `-- temp-alert.sh # CPU temperature alerts
| `-- python/
| +-- disk-monitor.py # Disk usage monitor
| `-- port-scanner.py # TCP port scanner
+-- config/
| `-- systemd/ # Systemd service files
`-- docs/
 `-- guides/ # How-to guides
```

## Quick Start

```bash
# Clone the repo
git clone https://github.com/magos-cyber/sysadmin-bash-toolkit.git
cd sysadmin-bash-toolkit

# Make scripts executable
chmod +x scripts/bash/*.sh scripts/monitoring/*.sh

# Run a script
sudo bash scripts/bash/server-setup.sh
```

## Contents

### Kernel & Container Security
- **`scripts/bash/kernel-hardening.sh`** — Comprehensive kernel security hardening (sysctl parameters, module blacklisting, GRUB audit)
- **`scripts/bash/container-security.sh`** — Docker/Podman security scanning & hardening audit (vulnerability scanning, CIS benchmark checks, daemon configuration)
- **`scripts/bash/log-forensics.sh`** — Log analysis & forensics tool for incident response (auth analysis, timeline building, IOC extraction, service health)
- **`scripts/bash/compliance-check.sh`** — CIS benchmark compliance checker (Level 1/2 checks for filesystem, services, SSH, PAM, logging, and more)

### Server Setup & Hardening
- **`scripts/bash/server-setup.sh`** — Initial Debian/Ubuntu server hardening (UFW, fail2ban, SSH, auto-updates, user creation)
- **`scripts/bash/docker-install.sh`** — Install Docker Engine + Compose with sane daemon defaults
- **`scripts/bash/security-hardening.sh`** — Apply baseline firewall (UFW) + Fail2Ban + sysctl hardening
- **`scripts/bash/security-scanner.sh`** — Automated security scanning with lynis-style checks, hardening suggestions, and detailed reporting

### Automation & Updates
- **`scripts/bash/auto-update.sh`** — Pull & recreate all Docker compose stacks, prune images, health-check services
- **`scripts/bash/vpn-setup.sh`** — WireGuard VPN server + `wg-add-client.sh` helper for peer configs
- **`scripts/bash/hass-update.sh`** — Pull latest Home Assistant image and restart container
- **`scripts/bash/kernel-update.sh`** — Safe kernel update with automatic backup and rollback capability

### Backup & Monitoring
- **`scripts/bash/backup-automator.sh`** — Rotating `.tar.gz` backups with optional Telegram notify
- **`scripts/bash/hass-backup.sh`** — Backup Home Assistant configuration (snapshot + rotation)
- **`scripts/monitoring/temp-alert.sh`** — CPU temperature alerts via Telegram (state-aware)
- **`scripts/bash/performance-monitor.sh`** — Continuous performance monitoring with customizable thresholds and alerting

### Python Utilities
- **`scripts/python/disk-monitor.py`** — Disk usage monitor with warning/critical thresholds + Telegram
- **`scripts/python/port-scanner.py`** — Multi-host TCP port scanner (common homelab ports)

## Configuration

Most scripts work out of the box. For Telegram alerts, edit the config at the top of each script:

```bash
export BOT_TOKEN="your-bot-token"
export CHAT_ID="your-chat-id"
```

## Examples

### Harden a new server
```bash
sudo bash scripts/bash/server-setup.sh
```

### Install Docker
```bash
sudo bash scripts/bash/docker-install.sh
```

### Setup WireGuard VPN
```bash
sudo bash scripts/bash/vpn-setup.sh
# Add a client:
sudo bash /etc/wireguard/wg-add-client.sh phone
```

### Auto-update all stacks (add to cron)
```bash
0 4 * * * /path/to/scripts/bash/auto-update.sh >> /var/log/auto-update.log 2>&1
```

### Monitor temperature (add to cron)
```bash
*/15 * * * * /path/to/scripts/monitoring/temp-alert.sh
```

### Perform security scan
```bash
# Standard scan
sudo bash scripts/bash/security-scanner.sh

# Quick scan
sudo bash scripts/bash/security-scanner.sh --quick

# Full scan
sudo bash scripts/bash/security-scanner.sh --full
```

### Update kernel safely
```bash
sudo bash scripts/bash/kernel-update.sh
```

### Monitor performance
```bash
# Default 5-minute interval
sudo bash scripts/bash/performance-monitor.sh

# Custom interval and thresholds
sudo bash scripts/bash/performance-monitor.sh --interval 60 --cpu-threshold 75 --memory-threshold 80
```

### Run for specific duration
```bash
# Run for 2 hours then stop
sudo bash scripts/bash/performance-monitor.sh --duration 2
```

### Kernel Hardening
```bash
# Audit current kernel security posture
sudo bash scripts/bash/kernel-hardening.sh --audit

# Apply kernel hardening protections
sudo bash scripts/bash/kernel-hardening.sh --apply

# Rollback to previous configuration
sudo bash scripts/bash/kernel-hardening.sh --rollback
```

### Container Security
```bash
# Scan container images for vulnerabilities
sudo bash scripts/bash/container-security.sh --scan

# Audit running containers and daemon configuration
sudo bash scripts/bash/container-security.sh --audit

# Run host/daemon benchmark checks
sudo bash scripts/bash/container-security.sh --benchmark
```

### Log Forensics
```bash
# Analyze authentication and SSH events
sudo bash scripts/bash/log-forensics.sh --analyze

# Build chronological event timeline
sudo bash scripts/bash/log-forensics.sh --timeline

# Extract Indicators of Compromise
sudo bash scripts/bash/log-forensics.sh --ioc

# Generate full forensics report
sudo bash scripts/bash/log-forensics.sh --report
```

### Compliance Checking
```bash
# Run CIS Level 1 compliance check (basic)
sudo bash scripts/bash/compliance-check.sh --level 1

# Run CIS Level 2 compliance check (strict)
sudo bash scripts/bash/compliance-check.sh --level 2

# Generate compliance report
sudo bash scripts/bash/compliance-check.sh --level 1 --report
```

## Security Notes

- Always change default passwords
- Use strong, unique credentials
- Review scripts before running in production
- Test in a safe environment first

## Contributing

Contributions are welcome! Please:
- Keep scripts in English
- Add proper error handling
- Document all parameters
- Test before submitting

## License

MIT License — see (LICENSE) for details.