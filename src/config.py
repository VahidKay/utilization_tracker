"""Configuration management module."""

import yaml
import logging
import os
from typing import Dict, Any


class Config:
    """Handles configuration loading and validation."""

    def __init__(self, config_path: str = None):
        """Initialize configuration.

        Args:
            config_path: Path to YAML configuration file
        """
        self.config_path = config_path
        self.config: Dict[str, Any] = {}
        self.logger = logging.getLogger(__name__)

        if not config_path or not os.path.exists(config_path):
            raise ValueError(f"Configuration file not found: {config_path}")

        self.load_config()

        # Construct full paths from directory + filename
        self._construct_paths()

    def load_config(self):
        """Load configuration from YAML file."""
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f)

            if not self.config:
                raise ValueError("Configuration file is empty")

            self.logger.info(f"Configuration loaded from {self.config_path}")

        except yaml.YAMLError as e:
            self.logger.error(f"Error parsing config file: {e}")
            raise
        except Exception as e:
            self.logger.error(f"Error loading config file: {e}")
            raise

    def _construct_paths(self):
        """Construct full paths from base directory."""
        import os

        # Get base directory from environment variable
        base_dir = os.environ.get('TRACKER_BASE_DIR')

        if not base_dir:
            # Fallback: use parent directory of config file location
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(self.config_path)))

        # Construct data and log directories relative to base directory
        data_dir = os.path.join(base_dir, 'data')
        log_dir = os.path.join(base_dir, 'logs')

        # Get filenames with defaults
        if 'database' not in self.config:
            self.config['database'] = {}
        if 'logging' not in self.config:
            self.config['logging'] = {}

        db_filename = self.get('database.filename', 'metrics.db')
        log_filename = self.get('logging.filename', 'tracker.log')

        # Construct full paths
        self.config['database']['path'] = os.path.join(data_dir, db_filename)
        self.config['logging']['path'] = os.path.join(log_dir, log_filename)

    def get(self, key: str, default=None):
        """Get configuration value.

        Args:
            key: Configuration key (supports dot notation, e.g., 'database.path')
            default: Default value if key not found

        Returns:
            Configuration value
        """
        keys = key.split('.')
        value = self.config

        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
                if value is None:
                    return default
            else:
                return default

        return value

    def __getitem__(self, key: str):
        """Dictionary-style access to configuration.

        Args:
            key: Configuration key

        Returns:
            Configuration value
        """
        return self.get(key)

    def validate(self) -> bool:
        """Validate configuration values.

        Returns:
            True if configuration is valid

        Raises:
            ValueError: If configuration is invalid
        """
        if self.config['collection_interval'] < 1:
            raise ValueError("collection_interval must be at least 1 second")

        if self.config['retention_days'] < 1:
            raise ValueError("retention_days must be at least 1 day")

        return True
