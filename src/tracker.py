#!/usr/bin/env python3
"""Main utilization tracker daemon."""

import signal
import sys
import time
import logging
import os
from pathlib import Path
from logging.handlers import RotatingFileHandler

from config import Config
from collector import MetricsCollector
from database import MetricsDatabase


class UtilizationTracker:
    """Main tracker daemon that orchestrates metrics collection."""

    def __init__(self, config_path: str = None):
        """Initialize tracker.

        Args:
            config_path: Path to configuration file
        """
        self.config = Config(config_path)
        self.config.validate()

        self.running = False
        self.collector = MetricsCollector()
        self.db = None

        self._setup_logging()
        self._setup_signal_handlers()

    def _setup_logging(self):
        """Configure logging with rotation."""
        log_path = self.config.get('logging.path')
        log_level = self.config.get('logging.level', 'INFO')
        max_bytes = self.config.get('logging.max_bytes', 10485760)
        backup_count = self.config.get('logging.backup_count', 5)

        # Create log directory if it doesn't exist
        log_dir = os.path.dirname(log_path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)

        # Configure root logger
        logger = logging.getLogger()
        logger.setLevel(getattr(logging, log_level.upper()))

        # File handler with rotation
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=max_bytes,
            backupCount=backup_count
        )
        file_handler.setFormatter(
            logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        )
        logger.addHandler(file_handler)

        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(
            logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        )
        logger.addHandler(console_handler)

        self.logger = logging.getLogger(__name__)
        self.logger.info("Logging configured")

    def _setup_signal_handlers(self):
        """Setup handlers for graceful shutdown."""
        signal.signal(signal.SIGTERM, self._handle_shutdown)
        signal.signal(signal.SIGINT, self._handle_shutdown)

    def _handle_shutdown(self, signum, frame):
        """Handle shutdown signals.

        Args:
            signum: Signal number
            frame: Current stack frame
        """
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False

    def _setup_database(self):
        """Initialize database connection."""
        db_path = self.config.get('database.path')

        # Create database directory if it doesn't exist
        db_dir = os.path.dirname(db_path)
        if db_dir:
            os.makedirs(db_dir, exist_ok=True)

        self.db = MetricsDatabase(db_path)
        self.db.connect()

    def _collect_and_store(self):
        """Collect metrics and store in database."""
        try:
            # Collect system metrics
            if self.config.get('metrics.cpu') or self.config.get('metrics.memory'):
                system_metrics = self.collector.collect_system_metrics()
                self.db.insert_system_metrics(system_metrics)

            # Collect disk metrics
            if self.config.get('metrics.disk'):
                disk_metrics = self.collector.collect_disk_metrics()
                if disk_metrics:
                    self.db.insert_disk_metrics(disk_metrics)

            # Collect temperature metrics
            if self.config.get('metrics.temperature'):
                temp_metrics = self.collector.collect_temperature_metrics()
                if temp_metrics:
                    self.db.insert_temperature_metrics(temp_metrics)

            self.logger.debug("Metrics collected and stored successfully")

        except Exception as e:
            self.logger.error(f"Error during metrics collection: {e}", exc_info=True)

    def _cleanup_old_data(self):
        """Periodically cleanup old data based on retention policy."""
        retention_days = self.config.get('retention_days', 30)
        self.db.cleanup_old_data(retention_days)

    def run(self):
        """Main run loop for the tracker."""
        self.logger.info("Starting Utilization Tracker")

        # Display system info on startup
        system_info = self.collector.get_system_info()
        self.logger.info(f"System info: {system_info}")

        # Setup database
        self._setup_database()

        # Get collection interval
        interval = self.config.get('collection_interval', 60)
        self.logger.info(f"Collection interval: {interval} seconds")

        self.running = True
        collection_count = 0
        cleanup_interval = 86400  # Cleanup once per day
        last_cleanup = time.time()

        try:
            while self.running:
                start_time = time.time()

                # Collect and store metrics
                self._collect_and_store()
                collection_count += 1

                # Periodic cleanup (once per day)
                if time.time() - last_cleanup > cleanup_interval:
                    self._cleanup_old_data()
                    last_cleanup = time.time()

                # Calculate sleep time to maintain consistent interval
                elapsed = time.time() - start_time
                sleep_time = max(0, interval - elapsed)

                if sleep_time > 0:
                    time.sleep(sleep_time)
                else:
                    self.logger.warning(
                        f"Collection took {elapsed:.2f}s, longer than interval {interval}s"
                    )

        except KeyboardInterrupt:
            self.logger.info("Interrupted by user")
        except Exception as e:
            self.logger.error(f"Fatal error in main loop: {e}", exc_info=True)
            raise
        finally:
            self.shutdown()

    def shutdown(self):
        """Cleanup and shutdown tracker."""
        self.logger.info("Shutting down tracker")
        if self.db:
            self.db.close()
        self.logger.info("Tracker stopped")


def main():
    """Entry point for the tracker."""
    # Get config path from environment or use default
    config_path = os.environ.get('TRACKER_CONFIG', '/etc/utilization-tracker/config.yaml')

    # If config doesn't exist at default location, look in current directory
    if not os.path.exists(config_path):
        local_config = os.path.join(os.path.dirname(__file__), '..', 'config.yaml')
        if os.path.exists(local_config):
            config_path = local_config
        else:
            config_path = None

    tracker = UtilizationTracker(config_path)
    tracker.run()


if __name__ == '__main__':
    main()
