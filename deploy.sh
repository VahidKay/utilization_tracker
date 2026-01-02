#!/bin/bash
# Deployment script for Utilization Tracker
# Run this script locally to deploy to remote Ubuntu server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <user@remote-host> [ssh-port]${NC}"
    echo "Example: $0 user@192.168.1.100"
    echo "Example: $0 user@example.com 2222"
    exit 1
fi

REMOTE_HOST="$1"
SSH_PORT="${2:-22}"
TEMP_DIR="/tmp/utilization-tracker-deploy-$$"

echo -e "${GREEN}=== Deploying Utilization Tracker to $REMOTE_HOST ===${NC}"

# Test SSH connection
echo -e "${GREEN}[1/5] Testing SSH connection...${NC}"
if ! ssh -p "$SSH_PORT" -o ConnectTimeout=5 "$REMOTE_HOST" "echo 'Connection successful'" &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to $REMOTE_HOST${NC}"
    echo "Please check:"
    echo "  - Host address is correct"
    echo "  - SSH port is correct (current: $SSH_PORT)"
    echo "  - SSH keys are set up or password authentication is enabled"
    exit 1
fi
echo -e "${GREEN}SSH connection successful${NC}"

# Create temporary directory
echo -e "${GREEN}[2/5] Creating deployment package...${NC}"
mkdir -p "$TEMP_DIR"

# Copy files to temporary directory
cp -r src "$TEMP_DIR/"
cp config.yaml "$TEMP_DIR/"
cp requirements.txt "$TEMP_DIR/"
cp install.sh "$TEMP_DIR/"
mkdir -p "$TEMP_DIR/systemd"
cp systemd/utilization-tracker.service "$TEMP_DIR/systemd/"

# Create tarball
cd "$TEMP_DIR"
tar -czf utilization-tracker.tar.gz *
cd - > /dev/null

echo -e "${GREEN}[3/5] Transferring files to remote server...${NC}"
scp -P "$SSH_PORT" "$TEMP_DIR/utilization-tracker.tar.gz" "$REMOTE_HOST:/tmp/"

echo -e "${GREEN}[4/5] Extracting and installing on remote server...${NC}"
ssh -p "$SSH_PORT" "$REMOTE_HOST" << 'EOF'
    cd /tmp
    rm -rf utilization-tracker-install
    mkdir -p utilization-tracker-install
    cd utilization-tracker-install
    tar -xzf ../utilization-tracker.tar.gz

    echo "Running installation script..."
    sudo bash install.sh

    # Cleanup
    cd /tmp
    rm -rf utilization-tracker-install utilization-tracker.tar.gz
EOF

echo -e "${GREEN}[5/5] Cleaning up local temporary files...${NC}"
rm -rf "$TEMP_DIR"

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "The tracker has been installed on $REMOTE_HOST"
echo ""
echo "To start monitoring, run these commands on the remote server:"
echo -e "${YELLOW}sudo systemctl start utilization-tracker${NC}"
echo -e "${YELLOW}sudo systemctl enable utilization-tracker${NC}"
echo -e "${YELLOW}sudo systemctl status utilization-tracker${NC}"
echo ""
echo "Or run them remotely:"
echo -e "${YELLOW}ssh -p $SSH_PORT $REMOTE_HOST 'sudo systemctl start utilization-tracker && sudo systemctl enable utilization-tracker'${NC}"
echo ""
echo "To view logs remotely:"
echo -e "${YELLOW}ssh -p $SSH_PORT $REMOTE_HOST 'sudo journalctl -u utilization-tracker -f'${NC}"
