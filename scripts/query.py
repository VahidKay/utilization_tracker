#!/usr/bin/env python3
"""Query metrics from the database."""

import sqlite3
import sys
import os
from datetime import datetime, timedelta

# ============================================================================
# DATABASE QUERY FUNCTIONS
# ============================================================================

def fetch_system_metrics(cursor, agg_minutes=None, agg_func='AVG'):
    """Fetch system metrics from database.

    Returns list of tuples: (time_label, cpu_percent, memory_percent, load_avg_1)
    """
    if agg_minutes:
        cutoff_time = (datetime.now() - timedelta(minutes=agg_minutes)).isoformat()
        cursor.execute(f"""
            SELECT
                datetime('now', 'localtime') as time,
                {agg_func}(cpu_percent) as agg_cpu,
                {agg_func}(memory_percent) as agg_memory,
                {agg_func}(load_avg_1) as agg_load
            FROM system_metrics
            WHERE timestamp >= ?
        """, (cutoff_time,))
        row = cursor.fetchone()
        if row:
            return [row]
        else:
            return []
    else:
        cursor.execute("""
            SELECT
                datetime(timestamp, 'localtime') as time,
                cpu_percent,
                memory_percent,
                load_avg_1
            FROM system_metrics
            ORDER BY timestamp DESC
            LIMIT 1
        """)
        return cursor.fetchall()

def fetch_disk_metrics(cursor, agg_minutes=None, agg_func='AVG'):
    """Fetch disk metrics from database.

    Returns list of tuples: (mountpoint, used_percent, total_gb, used_gb, free_gb)
    """
    if agg_minutes:
        cutoff_time = (datetime.now() - timedelta(minutes=agg_minutes)).isoformat()
        cursor.execute(f"""
            SELECT
                mountpoint,
                {agg_func}(percent) as agg_percent,
                {agg_func}(total) / 1073741824.0 as agg_total_gb,
                {agg_func}(used) / 1073741824.0 as agg_used_gb,
                {agg_func}(free) / 1073741824.0 as agg_free_gb
            FROM disk_metrics
            WHERE timestamp >= ?
            GROUP BY mountpoint
            ORDER BY mountpoint
        """, (cutoff_time,))
    else:
        cursor.execute("""
            SELECT
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
    return cursor.fetchall()

def fetch_temperature_metrics(cursor, agg_minutes=None, agg_func='AVG'):
    """Fetch temperature metrics from database.

    Returns list of tuples: (sensor_name, label, temperature_celsius)
    """
    if agg_minutes:
        cutoff_time = (datetime.now() - timedelta(minutes=agg_minutes)).isoformat()
        cursor.execute(f"""
            SELECT
                sensor_name,
                label,
                {agg_func}(current) as agg_temperature
            FROM temperature_metrics
            WHERE timestamp >= ?
            GROUP BY sensor_name, label
            ORDER BY sensor_name, label
        """, (cutoff_time,))
    else:
        cursor.execute("""
            SELECT
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
    return cursor.fetchall()

def fetch_gpu_metrics(cursor, agg_minutes=None, agg_func='AVG'):
    """Fetch GPU metrics from database.

    Returns list of tuples: (gpu_index, gpu_name, gpu_utilization, memory_utilization,
                             memory_used_gb, memory_total_gb, temperature, power_draw, fan_speed)
    """
    if agg_minutes:
        cutoff_time = (datetime.now() - timedelta(minutes=agg_minutes)).isoformat()
        cursor.execute(f"""
            SELECT
                gpu_index,
                gpu_name,
                {agg_func}(gpu_utilization) as agg_gpu,
                {agg_func}(memory_utilization) as agg_mem,
                {agg_func}(memory_used) / 1073741824.0 as agg_mem_used_gb,
                {agg_func}(memory_total) / 1073741824.0 as agg_mem_total_gb,
                {agg_func}(temperature) as agg_temp,
                {agg_func}(power_draw) as agg_power,
                {agg_func}(fan_speed) as agg_fan
            FROM gpu_metrics
            WHERE timestamp >= ?
            GROUP BY gpu_index, gpu_name
            ORDER BY gpu_index
        """, (cutoff_time,))
    else:
        cursor.execute("""
            SELECT
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
    return cursor.fetchall()

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

def print_system_metrics(data):
    """Print system metrics.

    Expects list of tuples: (time_label, cpu_percent, memory_percent, load_avg_1)
    """
    print("=== System Metrics ===")
    print(f"{'Time':<20} {'CPU %':<9} {'Memory %':<11} {'Load 1m':<8}")
    print("-" * 50)

    if data:
        for row in data:
            print(f"{row[0]:<20} {row[1]:<9.1f} {row[2]:<11.1f} {row[3]:<8.2f}")
    else:
        print("No system metrics found")

def print_disk_metrics(data):
    """Print disk metrics.

    Expects list of tuples: (mountpoint, used_percent, total_gb, used_gb, free_gb)
    """
    print("\n=== Disk Metrics (Latest) ===")
    print(f"{'Mount Point':<25} {'Used %':<9} {'Total GB':<11} {'Used GB':<11} {'Free GB':<11}")
    print("-" * 70)

    if data:
        for row in data:
            print(f"{row[0]:<25} {row[1]:<9.1f} {row[2]:<11.1f} {row[3]:<11.1f} {row[4]:<11.1f}")
    else:
        print("No disk metrics found")

def print_temperature_metrics(data):
    """Print temperature metrics.

    Expects list of tuples: (sensor_name, label, temperature_celsius)
    """
    print("\n=== Temperature Metrics (Latest) ===")
    print(f"{'Sensor':<20} {'Label':<25} {'Temperature (°C)':<17}")
    print("-" * 60)

    if data:
        for row in data:
            print(f"{row[0]:<20} {row[1]:<25} {row[2]:<17.1f}")
    else:
        print("No temperature metrics found")

def print_gpu_metrics(data):
    """Print GPU metrics.

    Expects list of tuples: (gpu_index, gpu_name, gpu_utilization, memory_utilization,
                             memory_used_gb, memory_total_gb, temperature, power_draw, fan_speed)
    """
    print("\n=== GPU Metrics (Latest) ===")
    print(f"{'GPU':<5} {'Name':<28} {'GPU %':<8} {'Mem %':<8} {'Memory (GB)':<15} {'Temp (°C)':<12} {'Power (W)':<12} {'Fan %':<8}")
    print("-" * 100)

    if data:
        for row in data:
            gpu_idx, gpu_name, gpu_util, mem_util, mem_used_gb, mem_total_gb, temp, power, fan = row
            memory_str = f"{mem_used_gb:.1f}/{mem_total_gb:.1f}"
            temp_str = f"{temp:.0f}" if temp is not None else "N/A"
            power_str = f"{power:.1f}" if power is not None else "N/A"
            fan_str = f"{fan:.0f}" if fan is not None else "N/A"
            print(f"{gpu_idx:<5} {gpu_name:<28} {gpu_util:<8.1f} {mem_util:<8.1f} {memory_str:<15} {temp_str:<12} {power_str:<12} {fan_str:<8}")
    else:
        print("No GPU metrics found")

# ============================================================================
# MAIN QUERY FUNCTION
# ============================================================================

def query_metrics(db_path, agg_minutes=None, agg_func='AVG'):
    """Query and display recent metrics."""
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Fetch all data
        system_data = fetch_system_metrics(cursor, agg_minutes, agg_func)
        disk_data = fetch_disk_metrics(cursor, agg_minutes, agg_func)
        temp_data = fetch_temperature_metrics(cursor, agg_minutes, agg_func)
        gpu_data = fetch_gpu_metrics(cursor, agg_minutes, agg_func)

        conn.close()

        # Display all data
        print_system_metrics(system_data)
        print_gpu_metrics(gpu_data)
        print_disk_metrics(disk_data)
        print_temperature_metrics(temp_data)

    except sqlite3.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: query.py <db_path> [agg_minutes] [agg_func]", file=sys.stderr)
        print("  db_path      - Path to the database file", file=sys.stderr)
        print("  agg_minutes  - Show aggregates over last X minutes (optional)", file=sys.stderr)
        print("  agg_func     - Aggregation function: AVG or MAX (optional, default: AVG)", file=sys.stderr)
        sys.exit(1)

    db_path = sys.argv[1]
    agg_minutes = int(sys.argv[2]) if len(sys.argv) > 2 else None
    agg_func = sys.argv[3].upper() if len(sys.argv) > 3 else 'AVG'

    # Validate aggregation function
    if agg_func not in ['AVG', 'MAX']:
        print(f"Error: Invalid aggregation function '{agg_func}'. Must be AVG or MAX.", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(db_path):
        print(f"Database file not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    query_metrics(db_path, agg_minutes, agg_func)
