# Quick Deployment Guide

## Step-by-Step Instructions

### 1. Prepare for Deployment

Make sure you have SSH access to your Ubuntu server:
```bash
ssh user@your-server.com
```

### 2. Deploy from Your Local Machine

From the project directory on your local machine:

```bash
chmod +x deploy.sh
./deploy.sh user@your-server.com
```

The script will:
- Test SSH connection
- Create deployment package
- Transfer files to server
- Run installation automatically
- Clean up temporary files

### 3. Start Monitoring

After deployment completes, start the service:

```bash
# Start immediately and on every boot
ssh user@your-server.com 'sudo systemctl start utilization-tracker && sudo systemctl enable utilization-tracker'
```

### 4. Verify It's Working

Check the status:
```bash
ssh user@your-server.com 'sudo systemctl status utilization-tracker'
```

You should see "active (running)" in green.

### 5. View Collected Data

After a few minutes, check the data:

```bash
# Copy the analysis script to server
scp analysis/query_metrics.py user@your-server.com:/tmp/

# Run it on the server
ssh user@your-server.com 'sudo python3 /tmp/query_metrics.py'
```

Or query directly:
```bash
ssh user@your-server.com 'sudo sqlite3 /var/lib/utilization-tracker/metrics.db "SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 5;"'
```

## Customization

### Change Collection Interval

```bash
# Edit config on server
ssh user@your-server.com 'sudo nano /etc/utilization-tracker/config.yaml'

# Restart service
ssh user@your-server.com 'sudo systemctl restart utilization-tracker'
```

Default is 60 seconds. You can set it to:
- `10` for high-frequency monitoring (every 10 seconds)
- `300` for low-frequency monitoring (every 5 minutes)
- `3600` for hourly monitoring

### Disable Specific Metrics

Edit `/etc/utilization-tracker/config.yaml` and set metrics to `false`:

```yaml
metrics:
  cpu: true
  memory: true
  disk: true
  load_average: true
  temperature: false  # Disable temperature monitoring
```

## Monitoring Commands

### Real-time Logs
```bash
ssh user@your-server.com 'sudo journalctl -u utilization-tracker -f'
```

### Check Disk Space Used
```bash
ssh user@your-server.com 'sudo du -h /var/lib/utilization-tracker/metrics.db'
```

### Stop/Start Service
```bash
# Stop
ssh user@your-server.com 'sudo systemctl stop utilization-tracker'

# Start
ssh user@your-server.com 'sudo systemctl start utilization-tracker'

# Restart
ssh user@your-server.com 'sudo systemctl restart utilization-tracker'
```

## Troubleshooting

### Service Failed to Start

Check the logs:
```bash
ssh user@your-server.com 'sudo journalctl -u utilization-tracker -n 100 --no-pager'
```

### Python Dependencies Missing

Install them manually:
```bash
ssh user@your-server.com 'sudo pip3 install psutil pyyaml'
```

Or using apt:
```bash
ssh user@your-server.com 'sudo apt update && sudo apt install -y python3-psutil python3-yaml'
```

### Permission Denied Errors

Make sure the service is running as root:
```bash
ssh user@your-server.com 'ps aux | grep tracker.py'
```

You should see `root` as the user.

## Alternative: Manual Installation

If automatic deployment doesn't work, you can install manually:

1. Copy files to server:
```bash
scp -r * user@your-server.com:/tmp/utilization-tracker/
```

2. SSH to server and install:
```bash
ssh user@your-server.com
cd /tmp/utilization-tracker
sudo bash install.sh
sudo systemctl start utilization-tracker
sudo systemctl enable utilization-tracker
```

## Data Analysis

After collecting data for a while, analyze it:

```bash
# View summary of all collected data
ssh user@your-server.com 'sudo python3 /tmp/query_metrics.py'

# Or download database for local analysis
scp user@your-server.com:/var/lib/utilization-tracker/metrics.db ./metrics.db
sqlite3 metrics.db
```

## Next Steps

Once you have data collecting:

1. **Identify Peak Times**: Look for when CPU/memory usage is highest
2. **Find Idle Periods**: Look for times when resources are underutilized
3. **Capacity Planning**: Use trends to predict when you'll need more resources
4. **Optimization**: Identify processes or services that can be optimized

For Phase 2 features (network monitoring, process tracking), see [roadmap.md](roadmap.md).
