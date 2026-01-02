# Makefile Usage Guide

The Makefile provides convenient commands for deploying and managing the Utilization Tracker on your remote server.

## Initial Setup

### 1. Configure Remote Host

Edit [config.yaml](config.yaml) and set your server details:

```yaml
# Remote server connection
remote_host: "user@192.168.1.100"  # Change this to your server
ssh_port: 22
```

### 2. Quick Setup (All-in-One)

```bash
make setup
```

This will:
- Deploy the tracker to your server
- Start the service
- Enable it to run at boot
- Show status

## Common Commands

### Deployment

```bash
# First-time deployment
make deploy

# Update existing installation (stops service, deploys, restarts)
make redeploy
```

### Service Management

```bash
# Start the service
make start

# Stop the service
make stop

# Restart the service
make restart

# Check service status
make status

# Enable service at boot
make enable

# Disable service at boot
make disable
```

### Monitoring

```bash
# View live logs (press Ctrl+C to exit)
make logs

# View last 50 log entries
make logs-tail

# Query and display current metrics
make query

# Check database size
make disk-usage
```

### Maintenance

```bash
# Download database to local machine
make download-db

# Create backup on server
make backup-db

# Clean local temporary files
make clean
```

## Usage Examples

### Deploy and Start

```bash
# Deploy for the first time
make deploy

# Start and enable the service
make start enable

# Check it's running
make status
```

### Monitor Your Server

```bash
# Quick status check
make status

# View what's happening now
make logs-tail

# See live activity
make logs

# View collected metrics
make query
```

### Update the Code

```bash
# After making changes to the code
make redeploy

# Verify it restarted correctly
make status
```

### Troubleshooting

```bash
# Check if SSH connection works
make test-connection

# View recent logs for errors
make logs-tail

# Restart if something seems wrong
make restart
```

### Backup Your Data

```bash
# Create backup on server
make backup-db

# Download database locally
make download-db

# This creates ./data/metrics-YYYYMMDD-HHMMSS.db
```

## Configuration Changes

After editing [config.yaml](config.yaml) on your server:

```bash
# Restart to apply changes
make restart
```

To update the config file on the server:
1. Edit your local `config.yaml`
2. Run `make redeploy`

## Command Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make deploy` | Deploy to remote server |
| `make redeploy` | Stop, redeploy, and restart |
| `make start` | Start the service |
| `make stop` | Stop the service |
| `make restart` | Restart the service |
| `make status` | Check service status |
| `make enable` | Enable at boot |
| `make disable` | Disable at boot |
| `make logs` | Stream live logs |
| `make logs-tail` | Show last 50 logs |
| `make query` | Display metrics |
| `make disk-usage` | Check DB size |
| `make download-db` | Download database |
| `make backup-db` | Backup DB on server |
| `make clean` | Clean local temp files |
| `make setup` | Complete setup (deploy + start + enable) |
| `make test-connection` | Test SSH connection |

## Tips

### Combine Commands

You can run multiple make commands in sequence:

```bash
make deploy start enable status
```

### Use with Watch

Monitor status continuously:

```bash
watch -n 5 make status
```

### Quick Health Check

```bash
make status && make query
```

### After Server Reboot

Check if the service auto-started:

```bash
make status
```

If not enabled:

```bash
make enable
make start
```

## Troubleshooting

### "Please set remote_host in config.yaml"

Edit [config.yaml](config.yaml) and change:
```yaml
remote_host: "user@your-server.com"
```
to your actual server.

### SSH Connection Failed

1. Check the hostname: `ping your-server.com`
2. Check SSH access: `ssh user@your-server.com`
3. Verify port in config.yaml (usually 22)
4. Run: `make test-connection`

### Permission Denied

Make sure you have:
- SSH access to the server
- Sudo privileges on the server
- Correct username in `remote_host`

### Service Won't Start

```bash
# Check for errors
make logs-tail

# Try restarting
make restart

# If that fails, redeploy
make redeploy
```

## Advanced Usage

### Custom SSH Key

If you use a custom SSH key, modify your `~/.ssh/config`:

```
Host your-server
    HostName 192.168.1.100
    User youruser
    Port 22
    IdentityFile ~/.ssh/custom_key
```

Then use in config.yaml:
```yaml
remote_host: "your-server"
```

### Multiple Servers

Create separate config files:

```bash
# Copy config
cp config.yaml config-server1.yaml
cp config.yaml config-server2.yaml

# Edit each file with different remote_host

# Deploy to each
make deploy  # Uses config.yaml
```

For multiple servers, you might want to create server-specific Makefiles.

## What Gets Deployed

When you run `make deploy` or `make redeploy`, these files are transferred:

- `src/` - All Python source code
- `config.yaml` - Configuration file
- `requirements.txt` - Python dependencies
- `install.sh` - Installation script
- `systemd/utilization-tracker.service` - Systemd service file

The installation script then:
1. Creates directories
2. Installs dependencies
3. Copies files to `/opt/utilization-tracker/`
4. Sets up systemd service
5. Configures log rotation

## Next Steps

After deploying:

1. Wait a few minutes for data collection
2. Run `make query` to see metrics
3. Set up regular monitoring with `make logs`
4. Consider downloading database periodically with `make download-db`

See [README.md](README.md) for more details on configuration and [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for manual deployment options.
