# Quick Reference

## Setup (First Time)

```bash
# 1. Edit config.yaml - set your remote_host
vim config.yaml

# 2. Deploy, start, and enable
make setup

# 3. Verify
make status
```

## Daily Commands

```bash
make status        # Is it running?
make logs          # What's happening?
make query         # Show me the data
```

## Management

```bash
make start         # Start service
make stop          # Stop service
make restart       # Restart service
make enable        # Auto-start on boot
make disable       # Don't auto-start
```

## Deployment

```bash
make deploy        # First deployment
make redeploy      # Update after changes
```

## Monitoring

```bash
make logs          # Live logs (Ctrl+C to exit)
make logs-tail     # Last 50 lines
make query         # Current metrics
make disk-usage    # Database size
```

## Maintenance

```bash
make download-db   # Download database
make backup-db     # Backup on server
make clean         # Clean local files
```

## Troubleshooting

```bash
make test-connection  # Test SSH
make logs-tail        # Check for errors
make restart          # Try restarting
make redeploy         # Reinstall
```

## Configuration

Edit server details in [config.yaml](config.yaml):

```yaml
remote_host: "user@your-server.com"
ssh_port: 22
collection_interval: 60
retention_days: 365
```

## File Locations (on server)

| Path | Description |
|------|-------------|
| `/opt/utilization-tracker/` | Application files |
| `/etc/utilization-tracker/config.yaml` | Configuration |
| `/var/lib/utilization-tracker/metrics.db` | Database |
| `/var/log/utilization-tracker/tracker.log` | Log file |

## SSH Commands (alternative to make)

```bash
# Status
ssh user@server 'sudo systemctl status utilization-tracker'

# Start
ssh user@server 'sudo systemctl start utilization-tracker'

# Logs
ssh user@server 'sudo journalctl -u utilization-tracker -f'

# Query
ssh user@server 'sudo sqlite3 /var/lib/utilization-tracker/metrics.db "SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 5;"'
```

## Help

```bash
make help          # Show all commands
```

For detailed guides:
- [README.md](README.md) - Full documentation
- [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) - Makefile commands
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Deployment options
- [roadmap.md](roadmap.md) - Future features
