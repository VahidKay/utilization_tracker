#!/bin/bash
# Installation script for Utilization Tracker
# This script should be run on the Ubuntu server where you want to monitor resources

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/utilization-tracker"
CONFIG_DIR="/etc/utilization-tracker"
DATA_DIR="/var/lib/utilization-tracker"
LOG_DIR="/var/log/utilization-tracker"
SERVICE_FILE="/etc/systemd/system/utilization-tracker.service"

echo -e "${GREEN}=== Utilization Tracker Installation ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo "Install it with: sudo apt update && sudo apt install python3 python3-pip"
    exit 1
fi

echo -e "${GREEN}[1/7] Creating directories...${NC}"
mkdir -p "$INSTALL_DIR/src"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"

echo -e "${GREEN}[2/7] Installing Python dependencies...${NC}"
pip3 install psutil pyyaml || {
    echo -e "${YELLOW}Warning: pip3 install failed, trying with apt...${NC}"
    apt update
    apt install -y python3-psutil python3-yaml
}

echo -e "${GREEN}[3/7] Copying application files...${NC}"
cp -r src/* "$INSTALL_DIR/src/"
chmod +x "$INSTALL_DIR/src/tracker.py"
chmod +x "$INSTALL_DIR/src/query_remote.py" 2>/dev/null || true

echo -e "${GREEN}[4/7] Installing configuration file...${NC}"
if [ -f "$CONFIG_DIR/config.yaml" ]; then
    echo -e "${YELLOW}Configuration file already exists, creating backup...${NC}"
    cp "$CONFIG_DIR/config.yaml" "$CONFIG_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
fi
cp config.yaml "$CONFIG_DIR/config.yaml"

echo -e "${GREEN}[5/7] Installing systemd service...${NC}"
cp systemd/utilization-tracker.service "$SERVICE_FILE"

echo -e "${GREEN}[6/7] Reloading systemd daemon...${NC}"
systemctl daemon-reload

echo -e "${GREEN}[7/7] Setting up log rotation...${NC}"
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
echo "Next steps:"
echo "1. Review and customize the configuration:"
echo -e "   ${YELLOW}nano $CONFIG_DIR/config.yaml${NC}"
echo ""
echo "2. Start the service:"
echo -e "   ${YELLOW}sudo systemctl start utilization-tracker${NC}"
echo ""
echo "3. Enable the service to start on boot:"
echo -e "   ${YELLOW}sudo systemctl enable utilization-tracker${NC}"
echo ""
echo "4. Check service status:"
echo -e "   ${YELLOW}sudo systemctl status utilization-tracker${NC}"
echo ""
echo "5. View logs:"
echo -e "   ${YELLOW}sudo journalctl -u utilization-tracker -f${NC}"
echo -e "   ${YELLOW}sudo tail -f $LOG_DIR/tracker.log${NC}"
echo ""
echo "6. Check the database:"
echo -e "   ${YELLOW}sudo sqlite3 $DATA_DIR/metrics.db \"SELECT * FROM system_metrics ORDER BY timestamp DESC LIMIT 5;\"${NC}"
echo ""
echo -e "${GREEN}Database location: $DATA_DIR/metrics.db${NC}"
echo -e "${GREEN}Log location: $LOG_DIR/tracker.log${NC}"
