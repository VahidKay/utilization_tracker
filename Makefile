.PHONY: help deploy install start stop restart status enable disable logs query clean

# Read configuration from config.yaml
REMOTE_HOST := $(shell grep "^remote_host:" config.yaml | cut -d'"' -f2)
SSH_PORT := $(shell grep "^ssh_port:" config.yaml | awk '{print $$2}')
INSTALL_DIR := $(shell grep "install_dir:" config.yaml | cut -d'"' -f2)
CONFIG_DIR := $(shell grep "config_dir:" config.yaml | cut -d'"' -f2)
DATA_DIR := $(shell grep "data_dir:" config.yaml | cut -d'"' -f2)
LOG_DIR := $(shell grep "log_dir:" config.yaml | cut -d'"' -f2)
DB_FILENAME := $(shell awk '/^database:/,/^[a-z]/ { if (/filename:/) { gsub(/"/, ""); print $$2 } }' config.yaml)
LOG_FILENAME := $(shell awk '/^logging:/,/^[a-z]/ { if (/filename:/) { gsub(/"/, ""); print $$2 } }' config.yaml)
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
	@echo "Deployment:"
	@echo "  $(YELLOW)make deploy$(NC)      - Copy files to remote server"
	@echo "  $(YELLOW)make config$(NC)      - Show full configuration"
	@echo ""
	@echo "Service Management (run on server):"
	@echo "  $(YELLOW)make install$(NC)     - Install the tracker (run on server)"
	@echo "  $(YELLOW)make start$(NC)       - Start the tracker service"
	@echo "  $(YELLOW)make stop$(NC)        - Stop the tracker service"
	@echo "  $(YELLOW)make restart$(NC)     - Restart the tracker service"
	@echo "  $(YELLOW)make status$(NC)      - Check service status"
	@echo "  $(YELLOW)make enable$(NC)      - Enable service at boot"
	@echo "  $(YELLOW)make disable$(NC)     - Disable service at boot"
	@echo ""
	@echo "Monitoring (run on server):"
	@echo "  $(YELLOW)make logs$(NC)        - View live logs"
	@echo "  $(YELLOW)make logs-tail$(NC)   - View last 50 log lines"
	@echo "  $(YELLOW)make query$(NC)       - Query and display metrics"
	@echo "  $(YELLOW)make disk-usage$(NC)  - Check database disk usage"
	@echo ""
	@echo "Maintenance:"
	@echo "  $(YELLOW)make download-db$(NC) - Download database to local machine (from local)"
	@echo "  $(YELLOW)make backup-db$(NC)   - Create backup of database (run on server)"
	@echo "  $(YELLOW)make clean$(NC)       - Remove local temporary files"
	@echo ""
	@echo "Workflow:"
	@echo "  1. Edit $(YELLOW)config.yaml$(NC) and set your remote_host"
	@echo "  2. Run $(YELLOW)make deploy$(NC) from local machine"
	@echo "  3. SSH to server and run $(YELLOW)make install$(NC)"
	@echo "  4. Run $(YELLOW)make start enable$(NC) on server"
	@echo "  5. Run $(YELLOW)make status$(NC) on server to verify"

check-config:
	@if [ "$(REMOTE_HOST)" = "user@your-server.com" ]; then \
		echo "$(RED)Error: Please set remote_host in config.yaml$(NC)"; \
		exit 1; \
	fi

deploy: check-config
	@echo "$(GREEN)Copying files to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@chmod +x deploy.sh
	./deploy.sh $(REMOTE_HOST) $(SSH_PORT)

install:
	@echo "$(GREEN)Installing utilization tracker...$(NC)"
	@if [ ! -f install.sh ]; then \
		echo "$(RED)Error: install.sh not found. Are you in the project directory?$(NC)"; \
		exit 1; \
	fi
	@chmod +x install.sh
	sudo bash install.sh

start:
	@echo "$(GREEN)Starting tracker service...$(NC)"
	sudo systemctl start utilization-tracker
	@echo "$(GREEN)Service started$(NC)"
	@$(MAKE) status

stop:
	@echo "$(YELLOW)Stopping tracker service...$(NC)"
	sudo systemctl stop utilization-tracker
	@echo "$(YELLOW)Service stopped$(NC)"

restart:
	@echo "$(YELLOW)Restarting tracker service...$(NC)"
	sudo systemctl restart utilization-tracker
	@echo "$(GREEN)Service restarted$(NC)"
	@$(MAKE) status

status:
	@echo "$(GREEN)Service Status:$(NC)"
	@sudo systemctl status utilization-tracker --no-pager || true

enable:
	@echo "$(GREEN)Enabling tracker service at boot...$(NC)"
	sudo systemctl enable utilization-tracker
	@echo "$(GREEN)Service enabled$(NC)"

disable:
	@echo "$(YELLOW)Disabling tracker service at boot...$(NC)"
	sudo systemctl disable utilization-tracker
	@echo "$(YELLOW)Service disabled$(NC)"

logs:
	@echo "$(GREEN)Streaming logs (Ctrl+C to exit)...$(NC)"
	sudo journalctl -u utilization-tracker -f

logs-tail:
	@echo "$(GREEN)Last 50 log entries:$(NC)"
	sudo journalctl -u utilization-tracker -n 50 --no-pager

query:
	@echo "$(GREEN)Querying metrics...$(NC)"
	@sudo python3 src/query_remote.py || \
	sudo sqlite3 $(DB_PATH) "SELECT datetime(timestamp) as time, cpu_percent, memory_percent, load_avg_1 FROM system_metrics ORDER BY timestamp DESC LIMIT 10;"

disk-usage:
	@echo "$(GREEN)Database disk usage:$(NC)"
	@sudo du -h $(DB_PATH)
	@sudo sqlite3 $(DB_PATH) "SELECT COUNT(*) as system_records FROM system_metrics; SELECT COUNT(*) as disk_records FROM disk_metrics;"

download-db: check-config
	@echo "$(GREEN)Downloading database from $(REMOTE_HOST)...$(NC)"
	@mkdir -p ./data
	@scp -P $(SSH_PORT) $(REMOTE_HOST):$(DB_PATH) ./data/metrics-$$(date +%Y%m%d-%H%M%S).db
	@echo "$(GREEN)Database downloaded to ./data/$(NC)"

backup-db:
	@echo "$(GREEN)Creating database backup...$(NC)"
	@sudo cp $(DB_PATH) $(DATA_DIR)/metrics-backup-$$(date +%Y%m%d-%H%M%S).db
	@sudo ls -lh $(DATA_DIR)/metrics-backup-*.db | tail -5

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
	@rm -rf /tmp/utilization-tracker-deploy-* 2>/dev/null || true
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
	@echo "  Config Dir:    $(YELLOW)$(CONFIG_DIR)$(NC)"
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
