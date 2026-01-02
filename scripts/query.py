#!/usr/bin/env python3
"""Query metrics from the database."""

import sqlite3
import sys
import os

def query_metrics(db_path, limit=10):
    """Query and display recent metrics."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Query recent system metrics
        print("=== System Metrics ===")
        cursor.execute("""
            SELECT
                datetime(timestamp) as time,
                cpu_percent,
                memory_percent,
                load_avg_1
            FROM system_metrics
            ORDER BY timestamp DESC
            LIMIT ?
        """, (limit,))

        rows = cursor.fetchall()

        if rows:
            print(f"{'Time':<20} {'CPU %':<9} {'Memory %':<11} {'Load 1m':<8}")
            print("-" * 50)
            for row in rows:
                print(f"{row[0]:<20} {row[1]:<9.1f} {row[2]:<11.1f} {row[3]:<8.2f}")
        else:
            print("No system metrics found")

        # Query recent disk metrics (latest for each mount point)
        print("\n=== Disk Metrics (Latest) ===")
        cursor.execute("""
            SELECT
                datetime(d.timestamp) as time,
                d.mountpoint,
                d.percent as used_percent,
                d.total / 1073741824.0 as total_gb,
                d.used / 1073741824.0 as used_gb,
                d.free / 1073741824.0 as free_gb
            FROM disk_metrics d
            INNER JOIN (
                SELECT mountpoint, MAX(timestamp) as latest_ts
                FROM disk_metrics
                GROUP BY mountpoint
            ) latest ON d.mountpoint = latest.mountpoint AND d.timestamp = latest.latest_ts
            ORDER BY d.mountpoint
        """)

        disk_rows = cursor.fetchall()

        if disk_rows:
            print(f"{'Mount Point':<25} {'Used %':<9} {'Total GB':<11} {'Used GB':<11} {'Free GB':<11}")
            print("-" * 70)
            for row in disk_rows:
                print(f"{row[1]:<25} {row[2]:<9.1f} {row[3]:<11.1f} {row[4]:<11.1f} {row[5]:<11.1f}")
        else:
            print("No disk metrics found")

        # Query recent temperature metrics (latest for each sensor)
        print("\n=== Temperature Metrics (Latest) ===")
        cursor.execute("""
            SELECT
                datetime(t.timestamp) as time,
                t.sensor_name,
                t.label,
                t.current as temperature_celsius
            FROM temperature_metrics t
            INNER JOIN (
                SELECT sensor_name, label, MAX(timestamp) as latest_ts
                FROM temperature_metrics
                GROUP BY sensor_name, label
            ) latest ON t.sensor_name = latest.sensor_name
                AND t.label = latest.label
                AND t.timestamp = latest.latest_ts
            ORDER BY t.sensor_name, t.label
        """)

        temp_rows = cursor.fetchall()

        if temp_rows:
            print(f"{'Sensor':<20} {'Label':<25} {'Temperature (°C)':<17}")
            print("-" * 60)
            for row in temp_rows:
                print(f"{row[1]:<20} {row[2]:<25} {row[3]:<17.1f}")
        else:
            print("No temperature metrics found")

        # Query GPU metrics (latest for each GPU)
        print("\n=== GPU Metrics (Latest) ===")
        cursor.execute("""
            SELECT
                datetime(g.timestamp) as time,
                g.gpu_index,
                g.gpu_name,
                g.gpu_utilization,
                g.memory_utilization,
                g.memory_used / 1073741824.0 as memory_used_gb,
                g.memory_total / 1073741824.0 as memory_total_gb,
                g.temperature,
                g.power_draw,
                g.fan_speed
            FROM gpu_metrics g
            INNER JOIN (
                SELECT gpu_index, MAX(timestamp) as latest_ts
                FROM gpu_metrics
                GROUP BY gpu_index
            ) latest ON g.gpu_index = latest.gpu_index AND g.timestamp = latest.latest_ts
            ORDER BY g.gpu_index
        """)

        gpu_rows = cursor.fetchall()

        if gpu_rows:
            print(f"{'GPU':<5} {'Name':<28} {'GPU %':<8} {'Mem %':<8} {'Memory (GB)':<15} {'Temp (°C)':<12} {'Power (W)':<12} {'Fan %':<8}")
            print("-" * 100)
            for row in gpu_rows:
                memory_str = f"{row[5]:.1f}/{row[6]:.1f}"
                temp_str = f"{row[7]:.0f}" if row[7] is not None else "N/A"
                power_str = f"{row[8]:.1f}" if row[8] is not None else "N/A"
                fan_str = f"{row[9]:.0f}" if row[9] is not None else "N/A"
                print(f"{row[1]:<5} {row[2]:<28} {row[3]:<8.1f} {row[4]:<8.1f} {memory_str:<15} {temp_str:<12} {power_str:<12} {fan_str:<8}")
        else:
            print("No GPU metrics found")

        conn.close()

    except sqlite3.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: query.py <db_path> [limit]", file=sys.stderr)
        sys.exit(1)

    db_path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10

    if not os.path.exists(db_path):
        print(f"Database file not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    query_metrics(db_path, limit)
