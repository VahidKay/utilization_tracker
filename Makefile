.PHONY: help deploy sync install start stop restart status enable disable logs logs-tail \
        logs-failed query clean monitor verify view-data change-interval \
        check-config check-server config test-connection backup-db download-db disk-usage setup

# Read configuration from config.yaml
REMOTE_HOST := $(shell grep "^remote_host:" config.yaml | cut -d'"' -f2)
SSH_PORT := $(shell grep "^ssh_port:" config.yaml | awk '{print $$2}')
INSTALL_DIR := $(shell grep "install_dir:" config.yaml | cut -d'"' -f2)
VENV_DIR := $(shell grep "venv_dir:" config.yaml | cut -d'"' -f2)
DB_FILENAME := $(shell awk '/^database:/,/^[a-z]/ { if (/filename:/) { gsub(/"/, ""); print $$2 } }' config.yaml)
LOG_FILENAME := $(shell awk '/^logging:/,/^[a-z]/ { if (/filename:/) { gsub(/"/, ""); print $$2 } }' config.yaml)
DATA_DIR := $(INSTALL_DIR)/data
LOG_DIR := $(INSTALL_DIR)/logs
DB_PATH := $(DATA_DIR)/$(if $(DB_FILENAME),$(DB_FILENAME),metrics.db)
LOG_PATH := $(LOG_DIR)/$(if $(LOG_FILENAME),$(LOG_FILENAME),tracker.log)

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(GREEN)Utilization Tracker - Make Commands$(NC)"
	@echo ""
	@echo "Configuration:"
	@echo "  Remote Host:   $(YELLOW)$(REMOTE_HOST)$(NC)"
	@echo "  SSH Port:      $(YELLOW)$(SSH_PORT)$(NC)"
	@echo "  Install Dir:   $(YELLOW)$(INSTALL_DIR)$(NC)"
	@echo "  Data Dir:      $(YELLOW)$(DATA_DIR)$(NC)"
	@echo "  Database:      $(YELLOW)$(DB_PATH)$(NC)"
	@echo "  (Edit config.yaml to change)"
	@echo ""
	@echo "$(GREEN)═══ LOCAL MACHINE COMMANDS ═══$(NC)"
	@echo ""
	@echo "Deployment (run from your local machine):"
	@echo "  $(YELLOW)make deploy$(NC)          - Deploy files to remote server"
	@echo "  $(YELLOW)make sync$(NC)            - Sync local changes (faster)"
	@echo "  $(YELLOW)make download-db$(NC)     - Download database from server"
	@echo "  $(YELLOW)make test-connection$(NC) - Test SSH connection"
	@echo "  $(YELLOW)make config$(NC)          - Show full configuration"
	@echo "  $(YELLOW)make clean$(NC)           - Remove local temporary files"
	@echo ""
	@echo "$(GREEN)═══ SERVER COMMANDS (SSH required) ═══$(NC)"
	@echo ""
	@echo "Installation (run once on server):"
	@echo "  $(YELLOW)make install$(NC) - Install tracker, dependencies, and systemd service"
	@echo ""
	@echo "Service Management:"
	@echo "  $(YELLOW)make start$(NC)   - Start the service"
	@echo "  $(YELLOW)make stop$(NC)    - Stop the service"
	@echo "  $(YELLOW)make restart$(NC) - Restart the service"
	@echo "  $(YELLOW)make status$(NC)  - Check service status"
	@echo "  $(YELLOW)make enable$(NC)  - Enable service at boot"
	@echo "  $(YELLOW)make disable$(NC) - Disable service at boot"
	@echo ""
	@echo "Monitoring:"
	@echo "  $(YELLOW)make monitor$(NC)         - Live monitoring (every 60s)"
	@echo "  $(YELLOW)make verify$(NC)          - Verify tracker is working"
	@echo "  $(YELLOW)make view-data$(NC)       - View metrics (last 20)"
	@echo "  $(YELLOW)make logs$(NC)            - View live logs"
	@echo "  $(YELLOW)make logs-tail$(NC)       - View last 50 log lines"
	@echo "  $(YELLOW)make logs-failed$(NC)     - View failure logs"
	@echo "  $(YELLOW)make query$(NC)           - Display current metrics"
	@echo "  $(YELLOW)make query AVG=30$(NC)    - Display metrics + 30min averages"
	@echo "  $(YELLOW)make query MAX=5$(NC)     - Display metrics + 5min maximums"
	@echo "  $(YELLOW)make disk-usage$(NC)      - Check database size"
	@echo ""
	@echo "Configuration & Maintenance:"
	@echo "  $(YELLOW)make change-interval$(NC) - Change collection interval"
	@echo "  $(YELLOW)make backup-db$(NC)       - Create database backup"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  1. $(YELLOW)[Local]$(NC)  Edit config.yaml and set remote_host"
	@echo "  2. $(YELLOW)[Local]$(NC)  make deploy"
	@echo "  3. $(YELLOW)[Local]$(NC)  ssh $(REMOTE_HOST)"
	@echo "  4. $(YELLOW)[Server]$(NC) cd $(INSTALL_DIR) && make install"
	@echo "  5. $(YELLOW)[Server]$(NC) make start && make enable"
	@echo "  6. $(YELLOW)[Server]$(NC) make verify"

check-config:
	@if [ "$(REMOTE_HOST)" = "user@your-server.com" ]; then \
		echo "$(RED)Error: Please set remote_host in config.yaml$(NC)"; \
		exit 1; \
	fi

# Check if running on server (has systemd service installed)
check-server:
	@if [ ! -f /etc/systemd/system/utilization-tracker.service ]; then \
		echo "$(RED)Error: This command must be run on the server$(NC)"; \
		echo "$(YELLOW)Local commands: make deploy, make sync, make download-db, make test-connection, make config, make clean$(NC)"; \
		echo "$(YELLOW)Server commands must be run after SSH'ing to the server$(NC)"; \
		exit 1; \
	fi

deploy: check-config
	@echo "$(GREEN)Deploying to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@echo "$(GREEN)Target directory: $(INSTALL_DIR)$(NC)"
	@chmod +x scripts/deploy.sh
	@./scripts/deploy.sh $(REMOTE_HOST) $(SSH_PORT)
	@echo ""
	@echo "$(GREEN)Deployment complete!$(NC)"
	@echo ""
	@echo "To install and start on remote server:"
	@echo "  $(YELLOW)ssh -p $(SSH_PORT) $(REMOTE_HOST)$(NC)"
	@echo "  $(YELLOW)cd $(INSTALL_DIR)$(NC)"
	@echo "  $(YELLOW)make install$(NC)"
	@echo "  $(YELLOW)make start$(NC)"

# Sync local changes to remote (faster than full deploy, doesn't reinstall)
sync: check-config
	@echo "$(GREEN)Syncing to $(REMOTE_HOST):$(INSTALL_DIR)...$(NC)"
	@if ! command -v rsync >/dev/null 2>&1; then \
		echo "$(RED)Error: rsync not found. Please install rsync.$(NC)"; \
		exit 1; \
	fi
	@rsync -avz -e "ssh -p $(SSH_PORT)" \
		--exclude='.git' \
		--exclude='__pycache__' \
		--exclude='*.pyc' \
		--exclude='data' \
		--exclude='data/' \
		--exclude='.DS_Store' \
		--exclude='venv' \
		--exclude='venv/' \
		--exclude='config' \
		--exclude='config/' \
		--exclude='logs' \
		--exclude='logs/' \
		./ $(REMOTE_HOST):$(INSTALL_DIR)/
	@echo ""
	@echo "$(GREEN)Sync complete!$(NC)"
	@echo ""
	@echo "If you changed Python code, restart the service:"
	@echo "  $(YELLOW)ssh -p $(SSH_PORT) $(REMOTE_HOST) 'cd $(INSTALL_DIR) && make restart'$(NC)"

install: check-server
	@echo "$(GREEN)Installing utilization tracker...$(NC)"
	@if [ ! -f scripts/install.sh ]; then \
		echo "$(RED)Error: scripts/install.sh not found. Are you in the project directory?$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/install.sh
	sudo bash scripts/install.sh

start: check-server
	@echo "$(GREEN)Starting tracker service...$(NC)"
	sudo systemctl start utilization-tracker
	@echo "$(GREEN)Service started$(NC)"
	@$(MAKE) status

stop: check-server
	@echo "$(YELLOW)Stopping tracker service...$(NC)"
	sudo systemctl stop utilization-tracker
	@echo "$(YELLOW)Service stopped$(NC)"

restart: check-server
	@echo "$(YELLOW)Restarting tracker service...$(NC)"
	sudo systemctl restart utilization-tracker
	@echo "$(GREEN)Service restarted$(NC)"
	@$(MAKE) status

enable: check-server
	@echo "$(GREEN)Enabling tracker service at boot...$(NC)"
	sudo systemctl enable utilization-tracker
	@echo "$(GREEN)Service enabled at boot$(NC)"

disable: check-server
	@echo "$(YELLOW)Disabling tracker service at boot...$(NC)"
	sudo systemctl disable utilization-tracker
	@echo "$(YELLOW)Service disabled at boot$(NC)"

status: check-server
	@echo "$(GREEN)Service Status:$(NC)"
	@sudo systemctl status utilization-tracker --no-pager || true

logs: check-server
	@echo "$(GREEN)Streaming logs (Ctrl+C to exit)...$(NC)"
	sudo journalctl -u utilization-tracker -f

logs-tail: check-server
	@echo "$(GREEN)Last 50 log entries:$(NC)"
	sudo journalctl -u utilization-tracker -n 50 --no-pager

query: check-server
	@echo "$(GREEN)Querying metrics...$(NC)"
	@if [ -n "$(AVG)" ]; then \
		echo "$(YELLOW)(Showing averages over last $(AVG) minutes)$(NC)"; \
	elif [ -n "$(MAX)" ]; then \
		echo "$(YELLOW)(Showing maximums over last $(MAX) minutes)$(NC)"; \
	fi
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	VENV_DIR_EXPANDED=$$(echo "$(VENV_DIR)" | sed "s|^~|$$HOME|"); \
	if [ ! -f "$$DB_PATH_EXPANDED" ]; then \
		echo "$(RED)Database file not found at: $$DB_PATH_EXPANDED$(NC)"; \
		echo "$(YELLOW)Checking if service created database elsewhere...$(NC)"; \
		INSTALL_DIR_EXPANDED=$$(echo "$(INSTALL_DIR)" | sed "s|^~|$$HOME|"); \
		find $$INSTALL_DIR_EXPANDED -name "*.db" 2>/dev/null || echo "No database files found"; \
		exit 1; \
	fi; \
	if [ -d "$$VENV_DIR_EXPANDED" ]; then \
		if [ -n "$(AVG)" ]; then \
			$$VENV_DIR_EXPANDED/bin/python3 scripts/query.py $$DB_PATH_EXPANDED $(AVG) AVG; \
		elif [ -n "$(MAX)" ]; then \
			$$VENV_DIR_EXPANDED/bin/python3 scripts/query.py $$DB_PATH_EXPANDED $(MAX) MAX; \
		else \
			$$VENV_DIR_EXPANDED/bin/python3 scripts/query.py $$DB_PATH_EXPANDED; \
		fi; \
	else \
		if [ -n "$(AVG)" ]; then \
			python3 scripts/query.py $$DB_PATH_EXPANDED $(AVG) AVG; \
		elif [ -n "$(MAX)" ]; then \
			python3 scripts/query.py $$DB_PATH_EXPANDED $(MAX) MAX; \
		else \
			python3 scripts/query.py $$DB_PATH_EXPANDED; \
		fi; \
	fi

disk-usage: check-server
	@echo "$(GREEN)Database disk usage:$(NC)"
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	sudo du -h $$DB_PATH_EXPANDED; \
	sudo sqlite3 $$DB_PATH_EXPANDED "SELECT COUNT(*) as system_records FROM system_metrics; SELECT COUNT(*) as disk_records FROM disk_metrics;"

download-db: check-config
	@echo "$(GREEN)Downloading database from $(REMOTE_HOST)...$(NC)"
	@mkdir -p ./data
	@scp -P $(SSH_PORT) $(REMOTE_HOST):$(DB_PATH) ./data/metrics-$$(date +%Y%m%d-%H%M%S).db
	@echo "$(GREEN)Database downloaded to ./data/$(NC)"

backup-db: check-server
	@echo "$(GREEN)Creating database backup...$(NC)"
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	DATA_DIR_EXPANDED=$$(echo "$(DATA_DIR)" | sed "s|^~|$$HOME|"); \
	sudo cp $$DB_PATH_EXPANDED $$DATA_DIR_EXPANDED/metrics-backup-$$(date +%Y%m%d-%H%M%S).db; \
	sudo ls -lh $$DATA_DIR_EXPANDED/metrics-backup-*.db | tail -5

test-connection: check-config
	@echo "$(GREEN)Testing SSH connection to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@if ssh -p $(SSH_PORT) -o ConnectTimeout=5 $(REMOTE_HOST) "echo 'Connection successful'" 2>/dev/null; then \
		echo "$(GREEN)✓ Connection successful$(NC)"; \
	else \
		echo "$(RED)✗ Connection failed$(NC)"; \
		exit 1; \
	fi

clean:
	@echo "$(YELLOW)Cleaning local temporary files...$(NC)"
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@find . -type f -name ".DS_Store" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

config:
	@echo "$(GREEN)=== Configuration ===$(NC)"
	@echo ""
	@echo "Remote Server:"
	@echo "  Host:          $(YELLOW)$(REMOTE_HOST)$(NC)"
	@echo "  SSH Port:      $(YELLOW)$(SSH_PORT)$(NC)"
	@echo ""
	@echo "Installation Paths:"
	@echo "  Install Dir:   $(YELLOW)$(INSTALL_DIR)$(NC)"
	@echo "  Venv Dir:      $(YELLOW)$(VENV_DIR)$(NC)"
	@echo "  Data Dir:      $(YELLOW)$(DATA_DIR)$(NC)"
	@echo "  Log Dir:       $(YELLOW)$(LOG_DIR)$(NC)"
	@echo ""
	@echo "Database:"
	@echo "  Path:          $(YELLOW)$(DB_PATH)$(NC)"
	@echo ""
	@echo "Edit $(YELLOW)config.yaml$(NC) to change these settings"

# Quick setup target (run on server after deploying)
setup: install start enable
	@echo ""
	@echo "$(GREEN)================================$(NC)"
	@echo "$(GREEN)Setup Complete!$(NC)"
	@echo "$(GREEN)================================$(NC)"
	@echo ""
	@echo "The tracker is now:"
	@echo "  ✓ Installed"
	@echo "  ✓ Running"
	@echo "  ✓ Enabled at boot"
	@echo ""
	@echo "Useful commands:"
	@echo "  $(YELLOW)make status$(NC)  - Check status"
	@echo "  $(YELLOW)make logs$(NC)    - View logs"
	@echo "  $(YELLOW)make query$(NC)   - View metrics"
	@echo ""


# Start live monitoring (refreshes every 60 seconds)
monitor: check-server
	@echo "$(GREEN)Starting live monitoring (Ctrl+C to exit)...$(NC)"
	@echo ""
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	while true; do \
		clear; \
		echo "$(GREEN)=== Utilization Tracker - Live Monitor ===$(NC)"; \
		echo ""; \
		echo "$(YELLOW)Service Status:$(NC)"; \
		sudo systemctl is-active utilization-tracker --quiet && echo "  ✓ Running" || echo "  ✗ Stopped"; \
		echo ""; \
		echo "$(YELLOW)Latest Metrics:$(NC)"; \
		sudo sqlite3 $$DB_PATH_EXPANDED "SELECT datetime(timestamp, 'localtime') as time, cpu_percent || '%' as cpu, memory_percent || '%' as memory, load_avg_1 as load FROM system_metrics ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null || echo "  No data available"; \
		echo ""; \
		echo "$(YELLOW)Recent Activity (last 5 entries):$(NC)"; \
		sudo sqlite3 $$DB_PATH_EXPANDED "SELECT datetime(timestamp, 'localtime') as time, cpu_percent || '%' as cpu, memory_percent || '%' as mem FROM system_metrics ORDER BY timestamp DESC LIMIT 5;" 2>/dev/null || echo "  No data available"; \
		echo ""; \
		echo "Press Ctrl+C to exit"; \
		sleep 60; \
	done

# Verify tracker is working correctly
verify: check-server
	@echo "$(GREEN)Verifying Utilization Tracker...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Checking service status...$(NC)"
	@if sudo systemctl is-active utilization-tracker --quiet; then \
		echo "   ✓ Service is running"; \
	else \
		echo "   ✗ Service is not running"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(YELLOW)2. Checking database...$(NC)"
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	if [ -f "$$DB_PATH_EXPANDED" ]; then \
		echo "   ✓ Database exists at $$DB_PATH_EXPANDED"; \
	else \
		echo "   ✗ Database not found at $$DB_PATH_EXPANDED"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(YELLOW)3. Checking recent data collection...$(NC)"
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	LATEST=$$(sudo sqlite3 $$DB_PATH_EXPANDED "SELECT MAX(timestamp) FROM system_metrics;" 2>/dev/null); \
	if [ -n "$$LATEST" ]; then \
		echo "   ✓ Latest data: $$LATEST"; \
		RECORD_COUNT=$$(sudo sqlite3 $$DB_PATH_EXPANDED "SELECT COUNT(*) FROM system_metrics;" 2>/dev/null); \
		echo "   ✓ Total records: $$RECORD_COUNT"; \
	else \
		echo "   ✗ No data found in database"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(YELLOW)4. Checking log file...$(NC)"
	@LOG_PATH_EXPANDED=$$(echo "$(LOG_PATH)" | sed "s|^~|$$HOME|"); \
	if [ -f "$$LOG_PATH_EXPANDED" ]; then \
		echo "   ✓ Log file exists at $$LOG_PATH_EXPANDED"; \
		ERRORS=$$(sudo grep -c ERROR $$LOG_PATH_EXPANDED 2>/dev/null || echo 0); \
		echo "   ℹ Error count: $$ERRORS"; \
	else \
		echo "   ⚠ Log file not found at $$LOG_PATH_EXPANDED"; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Verification complete - tracker is working!$(NC)"

# View collected data (last 20 entries)
view-data: check-server
	@echo "$(GREEN)Viewing collected metrics (last 20 entries)...$(NC)"
	@echo ""
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	echo "$(YELLOW)System Metrics:$(NC)"; \
	sudo sqlite3 -header -column $$DB_PATH_EXPANDED "SELECT datetime(timestamp, 'localtime') as Time, cpu_percent || '%' as CPU, memory_percent || '%' as Memory, load_avg_1 as Load_1m FROM system_metrics ORDER BY timestamp DESC LIMIT 20;" 2>/dev/null || echo "No data available"
	@echo ""
	@DB_PATH_EXPANDED=$$(echo "$(DB_PATH)" | sed "s|^~|$$HOME|"); \
	echo "$(YELLOW)Disk Metrics (latest per mount):$(NC)"; \
	sudo sqlite3 -header -column $$DB_PATH_EXPANDED "SELECT datetime(timestamp, 'localtime') as Time, mount_point as Mount, used_percent || '%' as Used FROM disk_metrics WHERE timestamp IN (SELECT MAX(timestamp) FROM disk_metrics GROUP BY mount_point) ORDER BY mount_point LIMIT 10;" 2>/dev/null || echo "No disk data available"
	@echo ""
	@echo "To view more data, use: $(YELLOW)make query$(NC) or directly query the database"

# Change collection interval
change-interval: check-server
	@echo "$(GREEN)Change Collection Interval$(NC)"
	@echo ""
	@echo "Current interval: $(YELLOW)$$(grep 'collection_interval:' config.yaml | awk '{print $$2}') seconds$(NC)"
	@echo ""
	@echo "Common intervals:"
	@echo "  10   - Every 10 seconds (high frequency)"
	@echo "  30   - Every 30 seconds"
	@echo "  60   - Every minute (default)"
	@echo "  300  - Every 5 minutes"
	@echo "  600  - Every 10 minutes"
	@echo "  3600 - Every hour"
	@echo ""
	@read -p "Enter new interval in seconds: " interval; \
	if [ -n "$$interval" ] && [ "$$interval" -gt 0 ] 2>/dev/null; then \
		sed -i.bak "s/^collection_interval:.*/collection_interval: $$interval/" config.yaml && \
		echo "$(GREEN)✓ Interval updated to $$interval seconds$(NC)" && \
		echo "" && \
		echo "$(YELLOW)Don't forget to restart the service:$(NC)" && \
		echo "  make restart"; \
	else \
		echo "$(RED)Invalid interval. Please enter a positive number.$(NC)"; \
		exit 1; \
	fi

# View logs when service failed to start
logs-failed: check-server
	@echo "$(RED)Service Failure Logs$(NC)"
	@echo ""
	@echo "$(YELLOW)Recent errors from journalctl:$(NC)"
	@sudo journalctl -u utilization-tracker -p err -n 50 --no-pager
	@echo ""
	@echo "$(YELLOW)Full service status:$(NC)"
	@sudo systemctl status utilization-tracker --no-pager --full
	@echo ""
	@echo "$(YELLOW)Last 20 lines from log file:$(NC)"
	@LOG_PATH_EXPANDED=$$(echo "$(LOG_PATH)" | sed "s|^~|$$HOME|"); \
	if [ -f "$$LOG_PATH_EXPANDED" ]; then \
		sudo tail -20 $$LOG_PATH_EXPANDED; \
	else \
		echo "Log file not found at $$LOG_PATH_EXPANDED"; \
	fi
	@echo ""
	@echo "Common issues:"
	@echo "  - Missing Python dependencies: $(YELLOW)make install$(NC) (reinstall)"
	@echo "  - Permission errors: Check that service runs as root"
	@echo "  - Config file errors: Check $(YELLOW)config.yaml$(NC) syntax"
