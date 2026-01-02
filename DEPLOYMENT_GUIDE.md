# Deployment Guide

A comprehensive guide for deploying and managing the Utilization Tracker on your Ubuntu server.

## Prerequisites

- Ubuntu server (18.04 or newer)
- SSH access to the server
- Python 3.6+ on the server
- Root/sudo privileges on the server
- Make (optional, for convenient commands)

## Quick Start with Make Commands

### 1. Configure Your Server

Edit [config.yaml](config.yaml) and set your server details:

```yaml
remote_host: "user@your-server.com"
ssh_port: 22
```

### 2. Deploy Files

From your local machine, run:

```bash
make deploy
```

This will copy all files to your remote server at the `install_dir` location specified in `config.yaml` (default: `/opt/utilization-tracker`).

### 3. Install and Start

SSH to your server and run the installation:

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your custom install_dir
make install
make start
```

That's it! The tracker is now installed, running, and enabled at boot.

## Make Commands Reference

### Local Machine Commands

| Command                | Description                                    |
|------------------------|------------------------------------------------|
| `make deploy`          | Deploy files to remote server install_dir      |
| `make sync`            | Sync local changes to remote (faster, no reinstall) |
| `make config`          | Show current configuration                     |
| `make download-db`     | Download database from server                  |
| `make test-connection` | Test SSH connection to server                  |
| `make clean`           | Clean local temporary files                    |

### Server Commands

After deploying, SSH to your server (`ssh user@your-server.com`) and run these commands from your `install_dir` (e.g., `/opt/utilization-tracker`):

#### Service Management

| Command        | Description                       |
|----------------|-----------------------------------|
| `make start`   | Start service and enable at boot  |
| `make stop`    | Stop service and disable at boot  |
| `make restart` | Restart the service               |
| `make status`  | Check service status              |

#### Monitoring & Verification

| Command             | Description                                           |
|---------------------|-------------------------------------------------------|
| `make monitor`      | Start live monitoring dashboard (refreshes every 60s) |
| `make verify`       | Verify tracker is working correctly                   |
| `make view-data`    | View collected metrics (last 20 entries)              |
| `make logs`         | View live logs (Ctrl+C to exit)                       |
| `make logs-tail`    | View last 50 log lines                                |
| `make logs-failed`  | View logs when service failed to start                |
| `make query`        | Display current metrics                               |
| `make query AVG=30` | Display metrics + 30-minute averages                  |
| `make query MAX=5`  | Display metrics + 5-minute maximums                   |
| `make disk-usage`   | Check database size                                   |

#### Configuration Changes

| Command                | Description                              |
|------------------------|------------------------------------------|
| `make change-interval` | Interactively change collection interval |

#### Maintenance

| Command          | Description              |
|------------------|--------------------------|
| `make backup-db` | Create database backup   |

## Manual Deployment (Without Make)

If you prefer not to use Make, follow these steps:

### 1. Deploy Files

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh user@your-server.com
```

This copies files to the server at the `install_dir` specified in config.yaml.

### 2. Install and Start

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your custom install_dir
sudo bash scripts/install.sh
make start
make status
```

## Installation Paths

After installation, files are located at:

```
/opt/utilization-tracker/          # Main installation (or your custom install_dir)
├── src/                           # Application code
├── venv/                          # Python virtual environment
│   ├── bin/python3                # Python interpreter used by service
│   └── lib/                       # Installed packages (psutil, pyyaml)
├── config.yaml                    # Configuration file
├── data/                          # Database
│   └── metrics.db
└── logs/                          # Log files
    └── tracker.log
```

The install directory can be customized in [config.yaml](config.yaml) under `paths.install_dir`.

**Important:** The tracker uses a Python virtual environment at `$INSTALL_DIR/venv` to avoid conflicts with system packages. The systemd service automatically uses the Python interpreter from this venv.

## Configuration

### Edit Configuration

On the server:

```bash
ssh user@your-server.com
sudo nano /opt/utilization-tracker/config.yaml
```

Or locally before deploying (edit [config.yaml](config.yaml)).

### Collection Interval

#### Using Make Command (Recommended)

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make change-interval
```

This will:

1. Show the current interval
2. Prompt you to enter a new interval
3. Update the config file
4. Remind you to restart the service

Common intervals:

- `10` - Every 10 seconds (high frequency)
- `30` - Every 30 seconds
- `60` - Every minute (default)
- `300` - Every 5 minutes
- `600` - Every 10 minutes
- `3600` - Every hour

#### Manual Configuration

Edit the config file directly on the server (path is `$INSTALL_DIR/config.yaml` from your config.yaml settings):

```yaml
collection_interval: 60  # Seconds between collections
```

### Data Retention

```yaml
retention_days: 365  # Keep data for 1 year
```

Adjust based on your needs and disk space.

### Disable Specific Metrics

```yaml
metrics:
  cpu: true
  memory: true
  disk: true
  load_average: true
  temperature: false  # Disable if not available
```

### After Configuration Changes

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make restart
```

## Monitoring

### Live Monitoring Dashboard

Start a live monitoring dashboard that refreshes every 60 seconds:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make monitor
```

This displays:

- Service status (running/stopped)
- Latest metrics (CPU, memory, load)
- Recent activity (last 5 entries)

Press Ctrl+C to exit.

### Verify Tracker is Working

Run a comprehensive verification check:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make verify
```

This checks:

1. Service is running
2. Database exists
3. Recent data is being collected
4. Log file exists and error count

### View Collected Data

View the last 20 collected metrics in a formatted table:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make view-data
```

Shows both system metrics (CPU, memory, load) and disk metrics.

### Check Service Status

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make status
```

### View Real-time Logs

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make logs
```

Press Ctrl+C to exit.

### View Recent Log Entries

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make logs-tail
```

Shows the last 50 log entries.

### Query Metrics

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make query
```

### Check Database Size

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make disk-usage
```

### Download Database Locally

From your local machine:

```bash
make download-db
```

Database saved to `./data/metrics-YYYYMMDD-HHMMSS.db`

## Updating the Tracker

After making code changes locally, you have two options:

### Option 1: Quick Sync (Recommended for code changes)

Use `make sync` to quickly sync only the changed files:

```bash
make sync
```

This uses `rsync` to efficiently copy only the changed files to the remote server. Then restart the service:

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your custom install_dir
make restart
```

**Benefits:**
- Much faster than full deploy
- Only transfers changed files
- Doesn't reinstall dependencies or recreate venv
- Perfect for iterative development

### Option 2: Full Deploy (For major changes)

Use `make deploy` for a complete redeployment:

```bash
make deploy
```

Then SSH to server and reinstall:

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your custom install_dir
make install  # Only needed if dependencies changed
make restart
```

Use this when:
- Adding new Python dependencies
- Changing configuration structure
- Major refactoring

## Troubleshooting

### Service Won't Start

#### Quick Diagnosis

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make logs-failed
```

This command shows:

- Recent error messages from journalctl
- Full service status
- Last 20 lines from the log file
- Common issues and solutions

#### Install Missing Dependencies

If you see import errors or missing module errors:

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your custom install_dir
make install-deps
make restart
```

This will install Python dependencies (psutil, pyyaml) using pip3 or apt.

### Permission Errors

Ensure service runs as root:

```bash
ssh user@your-server.com
ps aux | grep tracker.py
```

Should show `root` as the user.

### Database Growing Too Large

1. Reduce retention days in config
2. Decrease collection frequency
3. Create backup and start fresh:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make backup-db
sudo rm /opt/utilization-tracker/data/metrics.db
make restart
```

### Can't Connect to Server

Test SSH connection:

```bash
make test-connection
```

If it fails, check:
- Server hostname/IP is correct in config.yaml
- SSH port is correct (usually 22)
- SSH keys are set up
- Server is reachable

## Data Analysis

### View Summary

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make query
```

### Direct SQL Queries

```bash
ssh user@your-server.com
sudo sqlite3 /opt/utilization-tracker/data/metrics.db
```

Example queries:

```sql
-- Latest metrics
SELECT datetime(timestamp) as time, cpu_percent, memory_percent
FROM system_metrics
ORDER BY timestamp DESC
LIMIT 10;

-- Average CPU over last 24 hours
SELECT AVG(cpu_percent) as avg_cpu
FROM system_metrics
WHERE timestamp >= datetime('now', '-24 hours');

-- Peak memory usage
SELECT MAX(memory_percent) as peak_memory, timestamp
FROM system_metrics;
```

### Download for Analysis

```bash
make download-db
sqlite3 ./data/metrics-*.db
```

## Uninstallation

To completely remove the tracker:

```bash
ssh user@your-server.com

# Stop and disable service
sudo systemctl stop utilization-tracker
sudo systemctl disable utilization-tracker

# Remove files
sudo rm /etc/systemd/system/utilization-tracker.service
sudo rm -rf /opt/utilization-tracker
sudo systemctl daemon-reload
```

## Advanced Configuration

### Custom Installation Directory

Edit [config.yaml](config.yaml) before deploying:

```yaml
paths:
  install_dir: "/usr/local/utilization-tracker"
  venv_dir: "/usr/local/utilization-tracker/venv"
```

Data and logs will be created automatically at `install_dir/data/` and `install_dir/logs/`.

### Multiple Servers

Use `make deploy` for each server, then SSH to each to run `make setup`.

Or create server-specific config files:

```bash
cp config.yaml config-server1.yaml
cp config.yaml config-server2.yaml
# Edit each with different remote_host
```

## Daily Operations

### Quick Health Check

Verify everything is working:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make verify
```

### View Latest Data

See recent metrics in a formatted table:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make view-data
```

### Live Dashboard

Watch metrics update in real-time:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make monitor
```

### Adjust Collection Frequency

Change how often metrics are collected:

```bash
ssh user@your-server.com
cd $INSTALL_DIR  # cd to your install_dir from config.yaml
make change-interval
# Follow prompts, then:
make restart
```

## Next Steps

Once your tracker is collecting data:

1. **Monitor Trends**: Use `make monitor` or `make view-data` to see patterns
2. **Verify Health**: Run `make verify` regularly to ensure tracker is working
3. **Set Up Alerts**: Add custom scripts to monitor thresholds
4. **Analyze Data**: Download database for detailed analysis with `make download-db`
5. **Optimize**: Identify resource bottlenecks and optimization opportunities

For future features (network monitoring, process tracking), see [roadmap.md](roadmap.md).

## Getting Help

Quick commands for troubleshooting:

- Check if tracker is working: `make verify`
- View recent logs: `make logs-tail`
- Debug startup failures: `make logs-failed`
- View configuration: `make config`
- Test SSH connection: `make test-connection`
- See all available commands: `make help`
