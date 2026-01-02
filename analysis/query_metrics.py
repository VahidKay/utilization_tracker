#!/usr/bin/env python3
"""Simple script to query and analyze collected metrics."""

import sqlite3
import sys
from datetime import datetime, timedelta
from typing import Optional


class MetricsAnalyzer:
    """Analyze collected utilization metrics."""

    def __init__(self, db_path: str = "/var/lib/utilization-tracker/metrics.db"):
        """Initialize analyzer.

        Args:
            db_path: Path to metrics database
        """
        self.db_path = db_path
        self.conn = None

    def connect(self):
        """Connect to database."""
        try:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row
        except sqlite3.Error as e:
            print(f"Error connecting to database: {e}")
            sys.exit(1)

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()

    def get_latest_metrics(self, limit: int = 10):
        """Get most recent system metrics.

        Args:
            limit: Number of records to retrieve
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                timestamp,
                cpu_percent,
                memory_percent,
                load_avg_1,
                load_avg_5
            FROM system_metrics
            ORDER BY timestamp DESC
            LIMIT ?
        """, (limit,))

        print(f"\n=== Latest {limit} System Metrics ===")
        print(f"{'Timestamp':<20} {'CPU %':<8} {'Memory %':<10} {'Load 1m':<10} {'Load 5m':<10}")
        print("-" * 70)

        for row in cursor.fetchall():
            print(f"{row['timestamp']:<20} {row['cpu_percent']:<8.1f} {row['memory_percent']:<10.1f} "
                  f"{row['load_avg_1']:<10.2f} {row['load_avg_5']:<10.2f}")

    def get_peak_usage(self, hours: int = 24):
        """Find peak CPU and memory usage in the last N hours.

        Args:
            hours: Number of hours to analyze
        """
        cutoff = datetime.now() - timedelta(hours=hours)
        cursor = self.conn.cursor()

        # Peak CPU
        cursor.execute("""
            SELECT timestamp, cpu_percent
            FROM system_metrics
            WHERE timestamp >= ?
            ORDER BY cpu_percent DESC
            LIMIT 1
        """, (cutoff.isoformat(),))

        peak_cpu = cursor.fetchone()

        # Peak Memory
        cursor.execute("""
            SELECT timestamp, memory_percent
            FROM system_metrics
            WHERE timestamp >= ?
            ORDER BY memory_percent DESC
            LIMIT 1
        """, (cutoff.isoformat(),))

        peak_memory = cursor.fetchone()

        print(f"\n=== Peak Usage (Last {hours} hours) ===")
        if peak_cpu:
            print(f"Peak CPU: {peak_cpu['cpu_percent']:.1f}% at {peak_cpu['timestamp']}")
        if peak_memory:
            print(f"Peak Memory: {peak_memory['memory_percent']:.1f}% at {peak_memory['timestamp']}")

    def get_average_usage(self, hours: int = 24):
        """Calculate average CPU and memory usage.

        Args:
            hours: Number of hours to analyze
        """
        cutoff = datetime.now() - timedelta(hours=hours)
        cursor = self.conn.cursor()

        cursor.execute("""
            SELECT
                AVG(cpu_percent) as avg_cpu,
                AVG(memory_percent) as avg_memory,
                AVG(load_avg_1) as avg_load,
                COUNT(*) as sample_count
            FROM system_metrics
            WHERE timestamp >= ?
        """, (cutoff.isoformat(),))

        row = cursor.fetchone()

        print(f"\n=== Average Usage (Last {hours} hours) ===")
        print(f"Average CPU: {row['avg_cpu']:.1f}%")
        print(f"Average Memory: {row['avg_memory']:.1f}%")
        print(f"Average Load: {row['avg_load']:.2f}")
        print(f"Samples: {row['sample_count']}")

    def get_disk_usage(self):
        """Show current disk usage for all partitions."""
        cursor = self.conn.cursor()

        # Get latest timestamp
        cursor.execute("SELECT MAX(timestamp) as latest FROM disk_metrics")
        latest = cursor.fetchone()['latest']

        cursor.execute("""
            SELECT
                device,
                mountpoint,
                total,
                used,
                free,
                percent
            FROM disk_metrics
            WHERE timestamp = ?
            ORDER BY mountpoint
        """, (latest,))

        print(f"\n=== Disk Usage (as of {latest}) ===")
        print(f"{'Mountpoint':<20} {'Device':<15} {'Total':<12} {'Used':<12} {'Free':<12} {'%':<6}")
        print("-" * 85)

        for row in cursor.fetchall():
            total_gb = row['total'] / (1024**3)
            used_gb = row['used'] / (1024**3)
            free_gb = row['free'] / (1024**3)
            print(f"{row['mountpoint']:<20} {row['device']:<15} {total_gb:<12.1f} "
                  f"{used_gb:<12.1f} {free_gb:<12.1f} {row['percent']:<6.1f}")

    def get_temperature_summary(self):
        """Show recent temperature readings."""
        cursor = self.conn.cursor()

        cursor.execute("""
            SELECT
                sensor_name,
                label,
                AVG(current) as avg_temp,
                MAX(current) as max_temp,
                MIN(current) as min_temp
            FROM temperature_metrics
            WHERE timestamp >= datetime('now', '-24 hours')
            GROUP BY sensor_name, label
        """)

        rows = cursor.fetchall()

        if rows:
            print("\n=== Temperature Summary (Last 24 hours) ===")
            print(f"{'Sensor':<20} {'Label':<15} {'Avg °C':<10} {'Max °C':<10} {'Min °C':<10}")
            print("-" * 70)

            for row in rows:
                print(f"{row['sensor_name']:<20} {row['label']:<15} {row['avg_temp']:<10.1f} "
                      f"{row['max_temp']:<10.1f} {row['min_temp']:<10.1f}")
        else:
            print("\n=== No temperature data available ===")

    def get_data_summary(self):
        """Show summary of collected data."""
        cursor = self.conn.cursor()

        # System metrics
        cursor.execute("""
            SELECT
                MIN(timestamp) as first_record,
                MAX(timestamp) as last_record,
                COUNT(*) as total_records
            FROM system_metrics
        """)
        system = cursor.fetchone()

        # Disk metrics
        cursor.execute("SELECT COUNT(*) as count FROM disk_metrics")
        disk = cursor.fetchone()

        # Temperature metrics
        cursor.execute("SELECT COUNT(*) as count FROM temperature_metrics")
        temp = cursor.fetchone()

        print("\n=== Data Collection Summary ===")
        print(f"First Record: {system['first_record']}")
        print(f"Last Record: {system['last_record']}")
        print(f"System Metrics: {system['total_records']} records")
        print(f"Disk Metrics: {disk['count']} records")
        print(f"Temperature Metrics: {temp['count']} records")


def main():
    """Main entry point."""
    analyzer = MetricsAnalyzer()

    try:
        analyzer.connect()

        # Show various reports
        analyzer.get_data_summary()
        analyzer.get_latest_metrics(5)
        analyzer.get_average_usage(24)
        analyzer.get_peak_usage(24)
        analyzer.get_disk_usage()
        analyzer.get_temperature_summary()

        print("\n" + "="*70)
        print("For custom queries, use:")
        print("  sqlite3 /var/lib/utilization-tracker/metrics.db")
        print("="*70 + "\n")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        analyzer.close()


if __name__ == '__main__':
    main()
