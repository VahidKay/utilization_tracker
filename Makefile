.PHONY: help deploy install start stop restart status enable disable logs query clean

# Read remote host and port from config.yaml
REMOTE_HOST := $(shell grep "^remote_host:" config.yaml | cut -d'"' -f2)
SSH_PORT := $(shell grep "^ssh_port:" config.yaml | awk '{print $$2}')

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(GREEN)Utilization Tracker - Make Commands$(NC)"
	@echo ""
	@echo "Configuration:"
	@echo "  Remote Host: $(YELLOW)$(REMOTE_HOST)$(NC)"
	@echo "  SSH Port:    $(YELLOW)$(SSH_PORT)$(NC)"
	@echo "  (Edit config.yaml to change)"
	@echo ""
	@echo "Deployment:"
	@echo "  $(YELLOW)make deploy$(NC)      - Deploy tracker to remote server"
	@echo "  $(YELLOW)make redeploy$(NC)    - Stop service, redeploy, and restart"
	@echo ""
	@echo "Service Management (remote):"
	@echo "  $(YELLOW)make start$(NC)       - Start the tracker service"
	@echo "  $(YELLOW)make stop$(NC)        - Stop the tracker service"
	@echo "  $(YELLOW)make restart$(NC)     - Restart the tracker service"
	@echo "  $(YELLOW)make status$(NC)      - Check service status"
	@echo "  $(YELLOW)make enable$(NC)      - Enable service at boot"
	@echo "  $(YELLOW)make disable$(NC)     - Disable service at boot"
	@echo ""
	@echo "Monitoring:"
	@echo "  $(YELLOW)make logs$(NC)        - View live logs"
	@echo "  $(YELLOW)make logs-tail$(NC)   - View last 50 log lines"
	@echo "  $(YELLOW)make query$(NC)       - Query and display metrics"
	@echo "  $(YELLOW)make disk-usage$(NC)  - Check database disk usage"
	@echo ""
	@echo "Maintenance:"
	@echo "  $(YELLOW)make download-db$(NC) - Download database to local machine"
	@echo "  $(YELLOW)make backup-db$(NC)   - Create backup of database on server"
	@echo "  $(YELLOW)make clean$(NC)       - Remove local temporary files"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Edit $(YELLOW)config.yaml$(NC) and set your remote_host"
	@echo "  2. Run $(YELLOW)make deploy$(NC)"
	@echo "  3. Run $(YELLOW)make start enable$(NC)"
	@echo "  4. Run $(YELLOW)make status$(NC) to verify"

check-config:
	@if [ "$(REMOTE_HOST)" = "user@your-server.com" ]; then \
		echo "$(RED)Error: Please set remote_host in config.yaml$(NC)"; \
		exit 1; \
	fi

deploy: check-config
	@echo "$(GREEN)Deploying to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@chmod +x deploy.sh
	./deploy.sh $(REMOTE_HOST) $(SSH_PORT)

redeploy: check-config
	@echo "$(GREEN)Redeploying to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@echo "$(YELLOW)Stopping service...$(NC)"
	-@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl stop utilization-tracker' 2>/dev/null || true
	@echo "$(YELLOW)Deploying new version...$(NC)"
	@chmod +x deploy.sh
	./deploy.sh $(REMOTE_HOST) $(SSH_PORT)
	@echo "$(YELLOW)Starting service...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl start utilization-tracker'
	@echo "$(GREEN)Redeploy complete!$(NC)"
	@$(MAKE) status

start: check-config
	@echo "$(GREEN)Starting tracker service...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl start utilization-tracker'
	@echo "$(GREEN)Service started$(NC)"
	@$(MAKE) status

stop: check-config
	@echo "$(YELLOW)Stopping tracker service...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl stop utilization-tracker'
	@echo "$(YELLOW)Service stopped$(NC)"

restart: check-config
	@echo "$(YELLOW)Restarting tracker service...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl restart utilization-tracker'
	@echo "$(GREEN)Service restarted$(NC)"
	@$(MAKE) status

status: check-config
	@echo "$(GREEN)Service Status:$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl status utilization-tracker --no-pager' || true

enable: check-config
	@echo "$(GREEN)Enabling tracker service at boot...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl enable utilization-tracker'
	@echo "$(GREEN)Service enabled$(NC)"

disable: check-config
	@echo "$(YELLOW)Disabling tracker service at boot...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo systemctl disable utilization-tracker'
	@echo "$(YELLOW)Service disabled$(NC)"

logs: check-config
	@echo "$(GREEN)Streaming logs (Ctrl+C to exit)...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo journalctl -u utilization-tracker -f'

logs-tail: check-config
	@echo "$(GREEN)Last 50 log entries:$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo journalctl -u utilization-tracker -n 50 --no-pager'

query: check-config
	@echo "$(GREEN)Querying metrics...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo python3 -c "import sys; sys.path.insert(0, \"/opt/utilization-tracker\"); exec(open(\"/opt/utilization-tracker/src/query_remote.py\").read())"' || \
	ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo sqlite3 /var/lib/utilization-tracker/metrics.db "SELECT datetime(timestamp) as time, cpu_percent, memory_percent, load_avg_1 FROM system_metrics ORDER BY timestamp DESC LIMIT 10;"'

disk-usage: check-config
	@echo "$(GREEN)Database disk usage:$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo du -h /var/lib/utilization-tracker/metrics.db && sudo sqlite3 /var/lib/utilization-tracker/metrics.db "SELECT COUNT(*) as system_records FROM system_metrics; SELECT COUNT(*) as disk_records FROM disk_metrics;"'

download-db: check-config
	@echo "$(GREEN)Downloading database...$(NC)"
	@mkdir -p ./data
	@scp -P $(SSH_PORT) $(REMOTE_HOST):/var/lib/utilization-tracker/metrics.db ./data/metrics-$$(date +%Y%m%d-%H%M%S).db
	@echo "$(GREEN)Database downloaded to ./data/$(NC)"

backup-db: check-config
	@echo "$(GREEN)Creating database backup on server...$(NC)"
	@ssh -p $(SSH_PORT) $(REMOTE_HOST) 'sudo cp /var/lib/utilization-tracker/metrics.db /var/lib/utilization-tracker/metrics-backup-$$(date +%Y%m%d-%H%M%S).db && sudo ls -lh /var/lib/utilization-tracker/metrics-backup-*.db | tail -5'

install-local:
	@echo "$(GREEN)Installing locally (for testing)...$(NC)"
	@chmod +x install.sh
	@sudo ./install.sh

test-connection: check-config
	@echo "$(GREEN)Testing SSH connection to $(REMOTE_HOST):$(SSH_PORT)...$(NC)"
	@if ssh -p $(SSH_PORT) -o ConnectTimeout=5 $(REMOTE_HOST) "echo 'Connection successful'" 2>/dev/null; then \
		echo "$(GREEN)✓ Connection successful$(NC)"; \
	else \
		echo "$(RED)✗ Connection failed$(NC)"; \
		exit 1; \
	fi

upload-analysis:
	@echo "$(GREEN)Uploading analysis script...$(NC)"
	@scp -P $(SSH_PORT) analysis/query_metrics.py $(REMOTE_HOST):/tmp/
	@echo "$(GREEN)Run on server: ssh $(REMOTE_HOST) 'sudo python3 /tmp/query_metrics.py'$(NC)"

clean:
	@echo "$(YELLOW)Cleaning local temporary files...$(NC)"
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@rm -rf /tmp/utilization-tracker-deploy-* 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

# Quick setup target
setup: check-config deploy start enable
	@echo ""
	@echo "$(GREEN)================================$(NC)"
	@echo "$(GREEN)Setup Complete!$(NC)"
	@echo "$(GREEN)================================$(NC)"
	@echo ""
	@echo "The tracker is now:"
	@echo "  ✓ Deployed to $(REMOTE_HOST)"
	@echo "  ✓ Running"
	@echo "  ✓ Enabled at boot"
	@echo ""
	@echo "Useful commands:"
	@echo "  $(YELLOW)make status$(NC)  - Check status"
	@echo "  $(YELLOW)make logs$(NC)    - View logs"
	@echo "  $(YELLOW)make query$(NC)   - View metrics"
	@echo ""
