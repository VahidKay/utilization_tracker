"""Database module for storing utilization metrics."""

import sqlite3
import logging
from datetime import datetime, timedelta
from typing import Optional


class MetricsDatabase:
    """Handles SQLite database operations for metrics storage."""

    def __init__(self, db_path: str):
        """Initialize database connection.

        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
        self.conn: Optional[sqlite3.Connection] = None
        self.logger = logging.getLogger(__name__)

    def connect(self):
        """Establish database connection and create tables if needed."""
        try:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row
            self._create_tables()
            self.logger.info(f"Connected to database at {self.db_path}")
        except sqlite3.Error as e:
            self.logger.error(f"Database connection error: {e}")
            raise

    def _create_tables(self):
        """Create necessary tables if they don't exist."""
        cursor = self.conn.cursor()

        # System metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS system_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME NOT NULL,
                cpu_percent REAL NOT NULL,
                cpu_count INTEGER NOT NULL,
                load_avg_1 REAL,
                load_avg_5 REAL,
                load_avg_15 REAL,
                memory_total INTEGER NOT NULL,
                memory_available INTEGER NOT NULL,
                memory_percent REAL NOT NULL,
                memory_used INTEGER NOT NULL,
                swap_total INTEGER NOT NULL,
                swap_used INTEGER NOT NULL,
                swap_percent REAL NOT NULL
            )
        """)

        # Create index on timestamp for faster queries
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_timestamp
            ON system_metrics(timestamp)
        """)

        # Disk metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS disk_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME NOT NULL,
                device TEXT NOT NULL,
                mountpoint TEXT NOT NULL,
                total INTEGER NOT NULL,
                used INTEGER NOT NULL,
                free INTEGER NOT NULL,
                percent REAL NOT NULL
            )
        """)

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_disk_timestamp
            ON disk_metrics(timestamp)
        """)

        # Temperature metrics table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS temperature_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME NOT NULL,
                sensor_name TEXT NOT NULL,
                label TEXT NOT NULL,
                current REAL NOT NULL,
                high REAL,
                critical REAL
            )
        """)

        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_temp_timestamp
            ON temperature_metrics(timestamp)
        """)

        self.conn.commit()
        self.logger.info("Database tables created/verified")

    def insert_system_metrics(self, metrics: dict):
        """Insert system metrics into database.

        Args:
            metrics: Dictionary containing system metrics
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute("""
                INSERT INTO system_metrics (
                    timestamp, cpu_percent, cpu_count,
                    load_avg_1, load_avg_5, load_avg_15,
                    memory_total, memory_available, memory_percent, memory_used,
                    swap_total, swap_used, swap_percent
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                metrics['timestamp'],
                metrics['cpu_percent'],
                metrics['cpu_count'],
                metrics['load_avg_1'],
                metrics['load_avg_5'],
                metrics['load_avg_15'],
                metrics['memory_total'],
                metrics['memory_available'],
                metrics['memory_percent'],
                metrics['memory_used'],
                metrics['swap_total'],
                metrics['swap_used'],
                metrics['swap_percent']
            ))
            self.conn.commit()
        except sqlite3.Error as e:
            self.logger.error(f"Error inserting system metrics: {e}")
            raise

    def insert_disk_metrics(self, metrics_list: list):
        """Insert disk metrics into database.

        Args:
            metrics_list: List of disk metric dictionaries
        """
        try:
            cursor = self.conn.cursor()
            for metrics in metrics_list:
                cursor.execute("""
                    INSERT INTO disk_metrics (
                        timestamp, device, mountpoint,
                        total, used, free, percent
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    metrics['timestamp'],
                    metrics['device'],
                    metrics['mountpoint'],
                    metrics['total'],
                    metrics['used'],
                    metrics['free'],
                    metrics['percent']
                ))
            self.conn.commit()
        except sqlite3.Error as e:
            self.logger.error(f"Error inserting disk metrics: {e}")
            raise

    def insert_temperature_metrics(self, metrics_list: list):
        """Insert temperature metrics into database.

        Args:
            metrics_list: List of temperature metric dictionaries
        """
        try:
            cursor = self.conn.cursor()
            for metrics in metrics_list:
                cursor.execute("""
                    INSERT INTO temperature_metrics (
                        timestamp, sensor_name, label,
                        current, high, critical
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    metrics['timestamp'],
                    metrics['sensor_name'],
                    metrics['label'],
                    metrics['current'],
                    metrics['high'],
                    metrics['critical']
                ))
            self.conn.commit()
        except sqlite3.Error as e:
            self.logger.error(f"Error inserting temperature metrics: {e}")
            raise

    def cleanup_old_data(self, retention_days: int):
        """Remove data older than retention period.

        Args:
            retention_days: Number of days to retain data
        """
        try:
            cutoff_date = datetime.now() - timedelta(days=retention_days)
            cursor = self.conn.cursor()

            cursor.execute(
                "DELETE FROM system_metrics WHERE timestamp < ?",
                (cutoff_date,)
            )
            deleted_system = cursor.rowcount

            cursor.execute(
                "DELETE FROM disk_metrics WHERE timestamp < ?",
                (cutoff_date,)
            )
            deleted_disk = cursor.rowcount

            cursor.execute(
                "DELETE FROM temperature_metrics WHERE timestamp < ?",
                (cutoff_date,)
            )
            deleted_temp = cursor.rowcount

            self.conn.commit()

            if deleted_system > 0 or deleted_disk > 0 or deleted_temp > 0:
                self.logger.info(
                    f"Cleaned up old data: {deleted_system} system records, "
                    f"{deleted_disk} disk records, {deleted_temp} temperature records"
                )
        except sqlite3.Error as e:
            self.logger.error(f"Error cleaning up old data: {e}")

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()
            self.logger.info("Database connection closed")
