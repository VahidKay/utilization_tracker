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

### 2. Deploy to Server

```bash
# From your local machine
make deploy
```

Then SSH to the server and install:

```bash
ssh user@your-server.com
cd /opt/utilization-tracker  # or your install_dir from config.yaml
make install
make start
```

## Common Commands

### Deployment

```bash
# First-time deployment (from local machine)
make deploy

# Quick sync changed files (from local machine, faster)
make sync
```

### Service Management

```bash
# Start service and enable at boot
make start

# Stop service and disable at boot
make stop

# Restart the service
make restart

# Check service status
make status
```

### Monitoring

```bash
# View live logs (press Ctrl+C to exit)
make logs

# View last 50 log entries
make logs-tail

# Query and display current metrics
make query

# Show averages over last 30 minutes
make query AVG=30

# Show maximums over last 5 minutes
make query MAX=5

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

# Start and enable the service at boot
make start

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

# View current metrics
make query

# View averages over last 30 minutes
make query AVG=30

# View maximums over last 5 minutes
make query MAX=5
```

### Update the Code

```bash
# After making changes to the code (from local machine)
make sync

# SSH to server and restart
ssh user@your-server.com
cd /opt/utilization-tracker
make restart

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
# On the server, restart to apply changes
make restart
```

To update the config file on the server from local:
1. Edit your local `config.yaml`
2. Run `make sync` (from local machine)
3. SSH to server and run `make restart`

## Command Reference

### Local Machine Commands

These commands can only be run from your local machine:

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make deploy` | Deploy to remote server |
| `make sync` | Quick sync changed files (faster) |
| `make download-db` | Download database from server |
| `make test-connection` | Test SSH connection |
| `make config` | Show full configuration |
| `make clean` | Clean local temp files |

### Server Commands

These commands must be run on the server (after SSH):

| Command | Description |
|---------|-------------|
| `make install` | Install tracker and dependencies |
| `make install-deps` | Install Python dependencies only |
| `make start` | Start service and enable at boot |
| `make stop` | Stop service and disable at boot |
| `make restart` | Restart the service |
| `make status` | Check service status |
| `make logs` | Stream live logs |
| `make logs-tail` | Show last 50 logs |
| `make logs-failed` | View failure logs |
| `make query` | Display metrics |
| `make disk-usage` | Check DB size |
| `make monitor` | Live monitoring dashboard |
| `make verify` | Verify tracker is working |
| `make view-data` | View metrics (last 20) |
| `make change-interval` | Change collection interval |
| `make backup-db` | Backup database |

## Tips

### Combine Commands

You can run multiple make commands in sequence:

```bash
make deploy start status
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

The service should auto-start if enabled. Check status:

```bash
make status
```

If not running:

```bash
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
# Check for errors (on server)
make logs-tail

# Try restarting (on server)
make restart

# If that fails, sync from local and reinstall
make sync  # from local machine
# Then SSH to server:
make install
make start
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

When you run `make deploy` or `make sync`, these files are transferred:

- `src/` - All Python source code
- `config.yaml` - Configuration file
- `requirements.txt` - Python dependencies
- `scripts/install.sh` - Installation script
- `Makefile` - Make commands for server

The installation script (`make install` on server) then:
1. Creates install directory
2. Creates Python virtual environment
3. Installs dependencies (psutil, pyyaml) in venv
4. Copies application files
5. Sets up systemd service with TRACKER_BASE_DIR environment variable
6. Configures log rotation

## Next Steps

After deploying:

1. Wait a few minutes for data collection
2. Run `make query` to see metrics
3. Set up regular monitoring with `make logs`
4. Consider downloading database periodically with `make download-db`

See [README.md](README.md) for more details on configuration and [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for manual deployment options.
