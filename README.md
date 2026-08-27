# Sysadmin Bash Toolkit

Sysadmin Bash toolkit — server hardening, monitoring, backup automation, log management, and daily ops scripts. All scripts are production-ready with proper error handling and logging.

## 📁 Structure

```
sysadmin-bash-toolkit/
├── scripts/
│   ├── bash/
│   │   ├── server-setup.sh       # Initial server hardening
│   │   ├── docker-install.sh     # Install Docker & Compose
│   │   ├── auto-update.sh        # Auto-update Docker stacks
│   │   ├── vpn-setup.sh          # WireGuard VPN server
│   │   ├── backup-automator.sh   # Rotating backups
│   │   ├── security-hardening.sh # UFW + Fail2Ban + sysctl
│   │   ├── hass-backup.sh        # Home Assistant backup
│   │   └── hass-update.sh        # Home Assistant update
│   ├── monitoring/
│   │   └── temp-alert.sh         # CPU temperature alerts
│   └── python/
│       ├── disk-monitor.py       # Disk usage monitor
│       └── port-scanner.py       # TCP port scanner
├── config/
│   └── systemd/                  # Systemd service files
└── docs/
    └── guides/                   # How-to guides
```

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/magos-cyber/sysadmin-bash-toolkit.git
cd sysadmin-bash-toolkit

# Make scripts executable
chmod +x scripts/bash/*.sh scripts/monitoring/*.sh

# Run a script
sudo bash scripts/bash/server-setup.sh
```

## 📝 Contents

### 🔧 Server Setup & Hardening
- **`scripts/bash/server-setup.sh`** — Initial Debian/Ubuntu server hardening (UFW, fail2ban, SSH, auto-updates, user creation)
- **`scripts/bash/docker-install.sh`** — Install Docker Engine + Compose with sane daemon defaults
- **`scripts/bash/security-hardening.sh`** — Apply baseline firewall (UFW) + Fail2Ban + sysctl hardening

### 🔄 Automation & Updates
- **`scripts/bash/auto-update.sh`** — Pull & recreate all Docker compose stacks, prune images, health-check services
- **`scripts/bash/vpn-setup.sh`** — WireGuard VPN server + `wg-add-client.sh` helper for peer configs
- **`scripts/bash/hass-update.sh`** — Pull latest Home Assistant image and restart container

### 💾 Backup & Monitoring
- **`scripts/bash/backup-automator.sh`** — Rotating `.tar.gz` backups with optional Telegram notify
- **`scripts/bash/hass-backup.sh`** — Backup Home Assistant configuration (snapshot + rotation)
- **`scripts/monitoring/temp-alert.sh`** — CPU temperature alerts via Telegram (state-aware)

### 🐍 Python Utilities
- **`scripts/python/disk-monitor.py`** — Disk usage monitor with warning/critical thresholds + Telegram
- **`scripts/python/port-scanner.py`** — Multi-host TCP port scanner (common homelab ports)

## ⚙️ Configuration

Most scripts work out of the box. For Telegram alerts, edit the config at the top of each script:

```bash
export BOT_TOKEN="your-bot-token"
export CHAT_ID="your-chat-id"
```

## 📝 Examples

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

## 🔒 Security Notes

- Always change default passwords
- Use strong, unique credentials
- Review scripts before running in production
- Test in a safe environment first

## 🤝 Contributing

Contributions are welcome! Please:
- Keep scripts in English
- Add proper error handling
- Document all parameters
- Test before submitting

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.