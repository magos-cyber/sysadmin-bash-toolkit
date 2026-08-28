# Sysadmin Bash Toolkit

Essential Bash scripts for server hardening, monitoring, and maintenance.

## Categories

### Monitoring
- `performance-monitor.sh` - Real-time system dashboard
- `service-guardian.sh` - Automatic service recovery

### Maintenance
- `log-manager.sh` - Log rotation and archiving
- `kernel-tuning.sh` - Kernel parameter optimization

### Security
- `ssh-hardening.sh` - SSH configuration hardening

### Backup
- `db-backup.sh` - PostgreSQL/MySQL backup utility
- `incremental-backup.sh` - Space-efficient rsync backups
- `verify-backup.sh` - Backup integrity verification

## Usage

```bash
chmod +x *.sh
sudo ./ssh-hardening.sh
sudo ./incremental-backup.sh /data /backups
```

## Requirements

- Bash 4+
- Root access for system modifications

## License

MIT
