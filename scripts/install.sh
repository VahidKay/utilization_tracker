#!/bin/bash
# Installation script for Utilization Tracker
# This script should be run on the Ubuntu server where you want to monitor resources

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read configuration from config.yaml if it exists
if [ -f config.yaml ]; then
    INSTALL_DIR=$(grep "install_dir:" config.yaml | cut -d'"' -f2)
    VENV_DIR=$(grep "venv_dir:" config.yaml | cut -d'"' -f2)
    CONFIG_DIR=$(grep "config_dir:" config.yaml | cut -d'"' -f2)
    DATA_DIR=$(grep "data_dir:" config.yaml | cut -d'"' -f2)
    LOG_DIR=$(grep "log_dir:" config.yaml | cut -d'"' -f2)
else
    # Default configuration
    INSTALL_DIR="/opt/utilization-tracker"
    VENV_DIR="/opt/utilization-tracker/venv"
    CONFIG_DIR="/etc/utilization-tracker"
    DATA_DIR="/var/lib/utilization-tracker"
    LOG_DIR="/var/log/utilization-tracker"
fi

# Expand tilde in paths (use SUDO_USER's home if running with sudo)
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi

INSTALL_DIR="${INSTALL_DIR/#\~/$USER_HOME}"
VENV_DIR="${VENV_DIR/#\~/$USER_HOME}"
CONFIG_DIR="${CONFIG_DIR/#\~/$USER_HOME}"
DATA_DIR="${DATA_DIR/#\~/$USER_HOME}"
LOG_DIR="${LOG_DIR/#\~/$USER_HOME}"

# Fallback: if venv_dir not specified, use install_dir/venv
if [ -z "$VENV_DIR" ]; then
    VENV_DIR="$INSTALL_DIR/venv"
fi

SERVICE_FILE="/etc/systemd/system/utilization-tracker.service"

echo -e "${GREEN}=== Utilization Tracker Installation ===${NC}"
echo -e "${GREEN}Install Directory: $INSTALL_DIR${NC}"
echo -e "${GREEN}Venv Directory: $VENV_DIR${NC}"
echo -e "${GREEN}Config Directory: $CONFIG_DIR${NC}"
echo -e "${GREEN}Data Directory: $DATA_DIR${NC}"
echo -e "${GREEN}Log Directory: $LOG_DIR${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo "Install it with: sudo apt update && sudo apt install python3 python3-venv"
    exit 1
fi

echo -e "${GREEN}[1/8] Creating directories...${NC}"
mkdir -p "$INSTALL_DIR/src"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"

echo -e "${GREEN}[2/8] Creating Python virtual environment...${NC}"
# Remove old venv if it exists
if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Removing old virtual environment...${NC}"
    rm -rf "$VENV_DIR"
fi

# Create new venv
python3 -m venv "$VENV_DIR" || {
    echo -e "${YELLOW}venv creation failed, trying to install python3-venv...${NC}"
    apt update
    apt install -y python3-venv
    python3 -m venv "$VENV_DIR"
}

echo -e "${GREEN}[3/8] Installing Python dependencies in venv...${NC}"
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install psutil pyyaml || {
    echo -e "${YELLOW}Warning: pip install failed, trying with apt...${NC}"
    apt update
    apt install -y python3-psutil python3-yaml
}

echo -e "${GREEN}[4/8] Copying application files...${NC}"
# Only copy if we're not already in the install directory
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" != "$INSTALL_DIR" ]; then
    cp -r src/* "$INSTALL_DIR/src/"
else
    echo "Already in install directory, skipping copy..."
fi
chmod +x "$INSTALL_DIR/src/tracker.py"
chmod +x "$INSTALL_DIR/src/query_remote.py" 2>/dev/null || true

echo -e "${GREEN}[5/8] Installing configuration file...${NC}"
if [ -f "$CONFIG_DIR/config.yaml" ]; then
    echo -e "${YELLOW}Configuration file already exists, creating backup...${NC}"
    cp "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
fi
cp config.yaml "$CONFIG_DIR/config.yaml"

echo -e "${GREEN}[6/8] Installing systemd service...${NC}"
# Create service file with correct Python path
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=System Utilization Tracker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$VENV_DIR/bin/python3 $INSTALL_DIR/src/tracker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}[7/8] Reloading systemd daemon...${NC}"
systemctl daemon-reload

echo -e "${GREEN}[8/8] Setting up log rotation...${NC}"
cat > /etc/logrotate.d/utilization-tracker <<EOF
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo -e "${GREEN}Python virtual environment: $VENV_DIR${NC}"
echo -e "${GREEN}Database location: $DATA_DIR/metrics.db${NC}"
echo -e "${GREEN}Log location: $LOG_DIR/tracker.log${NC}"
echo ""
echo "Next steps:"
echo "1. Review and customize the configuration:"
echo -e "   ${YELLOW}nano $CONFIG_DIR/config.yaml${NC}"
echo ""
echo "2. Start the service (also enables at boot):"
echo -e "   ${YELLOW}make start${NC}"
echo ""
echo "3. Check service status:"
echo -e "   ${YELLOW}make status${NC}"
echo ""
echo "4. View logs:"
echo -e "   ${YELLOW}make logs${NC}"
echo -e "   ${YELLOW}sudo tail -f $LOG_DIR/tracker.log${NC}"
echo ""
echo "5. Check the database:"
echo -e "   ${YELLOW}sudo sqlite3 $DATA_DIR/metrics.db \"SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 5;\"${NC}"
