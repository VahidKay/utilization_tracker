#!/usr/bin/env python3
"""Quick query script for remote execution."""

import sqlite3
from datetime import datetime, timedelta

DB_PATH = "/var/lib/utilization-tracker/metrics.db"

try:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # Latest 5 records
    print("\n=== Latest 5 System Metrics ===")
    cursor.execute("""
        SELECT timestamp, cpu_percent, memory_percent, load_avg_1
        FROM system_metrics
        ORDER BY timestamp DESC
        LIMIT 5
    """)
    print(f"{'Time':<20} {'CPU %':<10} {'Memory %':<10} {'Load 1m':<10}")
    print("-" * 50)
    for row in cursor.fetchall():
        ts = row['timestamp'].split('.')[0] if '.' in row['timestamp'] else row['timestamp']
        print(f"{ts:<20} {row['cpu_percent']:<10.1f} {row['memory_percent']:<10.1f} {row['load_avg_1']:<10.2f}")

    # 24h averages
    cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
    cursor.execute("""
        SELECT AVG(cpu_percent) as avg_cpu, AVG(memory_percent) as avg_mem
        FROM system_metrics
        WHERE timestamp >= ?
    """, (cutoff,))
    row = cursor.fetchone()
    print(f"\n24h Avg - CPU: {row['avg_cpu']:.1f}%, Memory: {row['avg_mem']:.1f}%")

    conn.close()
except Exception as e:
    print(f"Error: {e}")
