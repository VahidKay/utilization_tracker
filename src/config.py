"""Configuration management module."""

import yaml
import logging
import os
from typing import Dict, Any


class Config:
    """Handles configuration loading and validation."""

    DEFAULT_CONFIG = {
        'collection_interval': 60,
        'database': {
            'path': '/var/lib/utilization-tracker/metrics.db'
        },
        'logging': {
            'path': '/var/log/utilization-tracker/tracker.log',
            'level': 'INFO',
            'max_bytes': 10485760,
            'backup_count': 5
        },
        'metrics': {
            'cpu': True,
            'memory': True,
            'disk': True,
            'load_average': True
        },
        'retention_days': 30
    }

    def __init__(self, config_path: str = None):
        """Initialize configuration.

        Args:
            config_path: Path to YAML configuration file
        """
        self.config_path = config_path
        self.config: Dict[str, Any] = self.DEFAULT_CONFIG.copy()
        self.logger = logging.getLogger(__name__)

        if config_path and os.path.exists(config_path):
            self.load_config()
        else:
            self.logger.info("Using default configuration")

    def load_config(self):
        """Load configuration from YAML file."""
        try:
            with open(self.config_path, 'r') as f:
                user_config = yaml.safe_load(f)

            if user_config:
                self._merge_config(user_config)
                self.logger.info(f"Configuration loaded from {self.config_path}")
            else:
                self.logger.warning(f"Empty config file, using defaults")

        except yaml.YAMLError as e:
            self.logger.error(f"Error parsing config file: {e}")
            raise
        except Exception as e:
            self.logger.error(f"Error loading config file: {e}")
            raise

    def _merge_config(self, user_config: Dict[str, Any]):
        """Merge user configuration with defaults.

        Args:
            user_config: User-provided configuration dictionary
        """
        for key, value in user_config.items():
            if key in self.config and isinstance(self.config[key], dict) and isinstance(value, dict):
                self.config[key].update(value)
            else:
                self.config[key] = value

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
