# Server Utilization Tracker

A lightweight Python tool for monitoring and recording resource utilization on Ubuntu servers. Collects CPU, memory, disk, and temperature metrics to help optimize server usage.

## Features

- **Comprehensive Metrics Collection**:
  - CPU usage and load averages
  - Memory and swap utilization
  - Disk space and usage per partition
  - System temperature sensors (when available)

- **Persistent Storage**: SQLite database for historical data analysis
- **Automatic Management**: Systemd service for continuous monitoring
- **Configurable**: YAML-based configuration for collection intervals and retention
- **Low Overhead**: Minimal CPU and memory footprint
- **Automatic Cleanup**: Configurable data retention with automatic cleanup

## Quick Start

### Prerequisites

- Ubuntu server (18.04 or newer recommended)
- SSH access to the server
- Python 3.6+
- Root/sudo privileges
- Make (optional, for convenient commands)

### Deployment (Using Makefile - Recommended)

1. **Edit [config.yaml](config.yaml)** and set your server:

```yaml
remote_host: "user@your-server.com"
ssh_port: 22
```

2. **Deploy and start** with a single command:

```bash
make setup
```

That's it! The tracker is now running on your server.

**Common commands:**

```bash
make status     # Check if running
make logs       # View live logs
make query      # See collected metrics
make restart    # Restart service
make redeploy   # Update after code changes
```

See [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for all commands.

### Deployment (Manual Method)

1. **From your local machine**, deploy to your remote server:

```bash
chmod +x deploy.sh
./deploy.sh user@your-server.com
```

Replace `user@your-server.com` with your server's SSH connection string.

2. **Start the service** (run on remote server or via SSH):

```bash
sudo systemctl start utilization-tracker
sudo systemctl enable utilization-tracker
```

3. **Verify it's running**:

```bash
sudo systemctl status utilization-tracker
```

### Manual Installation

If you prefer to install manually on the server:

1. Copy all files to the server
2. Run the installation script:

```bash
sudo bash install.sh
```

## Configuration

Edit `/etc/utilization-tracker/config.yaml`:

```yaml
# Collection interval in seconds (60 = 1 minute)
collection_interval: 60

# Database location
database:
  path: "/var/lib/utilization-tracker/metrics.db"

# Logging configuration
logging:
  path: "/var/log/utilization-tracker/tracker.log"
  level: "INFO"
  max_bytes: 10485760  # 10MB
  backup_count: 5

# Metrics to collect (set to false to disable)
metrics:
  cpu: true
  memory: true
  disk: true
  load_average: true
  temperature: true

# How many days to keep data
retention_days: 30
```

After changing configuration:
```bash
sudo systemctl restart utilization-tracker
```

## Monitoring

### Check Service Status
```bash
sudo systemctl status utilization-tracker
```

### View Real-time Logs
```bash
# Systemd journal
sudo journalctl -u utilization-tracker -f

# Application log
sudo tail -f /var/log/utilization-tracker/tracker.log
```

### Query Database

```bash
# View recent system metrics
sudo sqlite3 /var/lib/utilization-tracker/metrics.db \
  "SELECT timestamp, cpu_percent, memory_percent, load_avg_1
   FROM system_metrics
   ORDER BY timestamp DESC
   LIMIT 10;"

# View disk usage
sudo sqlite3 /var/lib/utilization-tracker/metrics.db \
  "SELECT timestamp, mountpoint, percent
   FROM disk_metrics
   ORDER BY timestamp DESC
   LIMIT 10;"

# View temperature readings
sudo sqlite3 /var/lib/utilization-tracker/metrics.db \
  "SELECT timestamp, sensor_name, label, current
   FROM temperature_metrics
   ORDER BY timestamp DESC
   LIMIT 10;"
```

## Database Schema

### system_metrics
- `timestamp`: When the measurement was taken
- `cpu_percent`: Overall CPU usage percentage
- `cpu_count`: Number of CPU cores
- `load_avg_1`, `load_avg_5`, `load_avg_15`: Load averages
- `memory_total`, `memory_available`, `memory_used`, `memory_percent`: Memory stats
- `swap_total`, `swap_used`, `swap_percent`: Swap memory stats

### disk_metrics
- `timestamp`: When the measurement was taken
- `device`: Device name (e.g., /dev/sda1)
- `mountpoint`: Where the device is mounted
- `total`, `used`, `free`: Space in bytes
- `percent`: Usage percentage

### temperature_metrics
- `timestamp`: When the measurement was taken
- `sensor_name`: Temperature sensor identifier
- `label`: Sensor label/location
- `current`: Current temperature (°C)
- `high`, `critical`: Threshold values

## Data Analysis

See [analysis/](analysis/) directory for example scripts to:
- Generate utilization reports
- Identify peak usage periods
- Detect anomalies
- Project capacity needs

## Troubleshooting

### Service won't start
```bash
# Check for errors
sudo journalctl -u utilization-tracker -n 50

# Verify Python dependencies
python3 -c "import psutil, yaml; print('Dependencies OK')"
```

### No temperature data
Temperature sensors may not be available on all systems, especially virtual machines. This is normal and won't affect other metrics.

### Permission errors
Ensure the service is running as root (required for full system access):
```bash
ps aux | grep tracker.py
```

### Database growing too large
Adjust `retention_days` in the configuration to keep less historical data, or decrease `collection_interval` to collect less frequently.

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop utilization-tracker
sudo systemctl disable utilization-tracker

# Remove files
sudo rm /etc/systemd/system/utilization-tracker.service
sudo rm -rf /opt/utilization-tracker
sudo rm -rf /etc/utilization-tracker
sudo rm -rf /var/lib/utilization-tracker
sudo rm -rf /var/log/utilization-tracker

# Reload systemd
sudo systemctl daemon-reload
```

## Project Structure

```
UtilizationTracker/
├── src/
│   ├── tracker.py      # Main daemon
│   ├── collector.py    # Metrics collection
│   ├── database.py     # Database operations
│   └── config.py       # Configuration management
├── systemd/
│   └── utilization-tracker.service  # Systemd unit file
├── config.yaml         # Configuration template
├── requirements.txt    # Python dependencies
├── install.sh         # Installation script
├── deploy.sh          # Remote deployment script
├── roadmap.md         # Project roadmap
└── README.md          # This file
```

## License

MIT License - Feel free to use and modify as needed.

## Contributing

This is a personal utility project. Feel free to fork and customize for your needs.
