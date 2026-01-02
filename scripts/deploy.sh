#!/bin/bash
# Deployment script for Utilization Tracker
# Run this script locally to copy files to remote Ubuntu server

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

# Read install_dir from config.yaml
if [ ! -f config.yaml ]; then
    echo -e "${RED}Error: config.yaml not found${NC}"
    exit 1
fi

INSTALL_DIR=$(grep "install_dir:" config.yaml | cut -d'"' -f2)
if [ -z "$INSTALL_DIR" ]; then
    echo -e "${RED}Error: install_dir not found in config.yaml${NC}"
    exit 1
fi

echo -e "${GREEN}=== Deploying Utilization Tracker to $REMOTE_HOST ===${NC}"
echo -e "${GREEN}Target directory: $INSTALL_DIR${NC}"

# Test SSH connection
echo -e "${GREEN}[1/2] Testing SSH connection...${NC}"
if ! ssh -p "$SSH_PORT" -o ConnectTimeout=5 "$REMOTE_HOST" "echo 'Connection successful'" &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to $REMOTE_HOST${NC}"
    echo "Please check:"
    echo "  - Host address is correct"
    echo "  - SSH port is correct (current: $SSH_PORT)"
    echo "  - SSH keys are set up or password authentication is enabled"
    exit 1
fi
echo -e "${GREEN}SSH connection successful${NC}"

# Create remote directory
echo -e "${GREEN}[2/2] Copying files to remote server...${NC}"
ssh -p "$SSH_PORT" "$REMOTE_HOST" "mkdir -p $INSTALL_DIR"

# Use rsync to copy files directly
if command -v rsync &> /dev/null; then
    rsync -avz --delete -e "ssh -p $SSH_PORT" \
        --exclude='.git' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='data' \
        --exclude='.DS_Store' \
        ./ "$REMOTE_HOST:$INSTALL_DIR/"
else
    # Fallback to scp if rsync not available
    echo -e "${YELLOW}rsync not found, using scp (slower)...${NC}"
    scp -P "$SSH_PORT" -r \
        src config.yaml requirements.txt scripts systemd Makefile \
        "$REMOTE_HOST:$INSTALL_DIR/"
fi

# Set execute permissions on scripts
ssh -p "$SSH_PORT" "$REMOTE_HOST" "chmod +x $INSTALL_DIR/scripts/install.sh"

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Files deployed to: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo -e "  ${YELLOW}ssh -p $SSH_PORT $REMOTE_HOST${NC}"
echo -e "  ${YELLOW}cd $INSTALL_DIR${NC}"
echo -e "  ${YELLOW}make install${NC}     (installs system files and dependencies)"
echo -e "  ${YELLOW}make start${NC}       (starts the service)"
echo -e "  ${YELLOW}make enable${NC}      (enables service at boot)"
