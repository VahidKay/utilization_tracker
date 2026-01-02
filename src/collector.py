"""Metrics collection module using psutil."""

import psutil
import logging
from datetime import datetime
from typing import Dict, List, Optional

# Try to import GPU libraries
try:
    import pynvml
    NVIDIA_GPU_AVAILABLE = True
except ImportError:
    NVIDIA_GPU_AVAILABLE = False


class MetricsCollector:
    """Collects system resource utilization metrics."""

    def __init__(self):
        """Initialize metrics collector."""
        self.logger = logging.getLogger(__name__)
        self.nvidia_initialized = False

        # Try to initialize NVIDIA GPU monitoring
        if NVIDIA_GPU_AVAILABLE:
            try:
                pynvml.nvmlInit()
                self.nvidia_initialized = True
                self.gpu_count = pynvml.nvmlDeviceGetCount()
                self.logger.info(f"NVIDIA GPU monitoring initialized: {self.gpu_count} GPU(s) detected")
            except Exception as e:
                self.logger.warning(f"Failed to initialize NVIDIA GPU monitoring: {e}")
                self.nvidia_initialized = False

    def collect_system_metrics(self) -> Dict:
        """Collect CPU, memory, and load average metrics.

        Returns:
            Dictionary containing system metrics
        """
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()

            # Load average (Unix-like systems only)
            try:
                load_avg = psutil.getloadavg()
                load_avg_1, load_avg_5, load_avg_15 = load_avg
            except (AttributeError, OSError):
                load_avg_1 = load_avg_5 = load_avg_15 = None

            # Memory metrics
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()

            metrics = {
                'timestamp': datetime.now().isoformat(),
                'cpu_percent': cpu_percent,
                'cpu_count': cpu_count,
                'load_avg_1': load_avg_1,
                'load_avg_5': load_avg_5,
                'load_avg_15': load_avg_15,
                'memory_total': memory.total,
                'memory_available': memory.available,
                'memory_percent': memory.percent,
                'memory_used': memory.used,
                'swap_total': swap.total,
                'swap_used': swap.used,
                'swap_percent': swap.percent
            }

            self.logger.debug(f"Collected system metrics: CPU={cpu_percent}%, Memory={memory.percent}%")
            return metrics

        except Exception as e:
            self.logger.error(f"Error collecting system metrics: {e}")
            raise

    def collect_disk_metrics(self) -> List[Dict]:
        """Collect disk usage metrics for all mounted partitions.

        Returns:
            List of dictionaries containing disk metrics
        """
        try:
            timestamp = datetime.now().isoformat()
            disk_metrics = []

            # Get all disk partitions
            partitions = psutil.disk_partitions(all=False)

            for partition in partitions:
                try:
                    # Skip special filesystems
                    if partition.fstype == '' or 'loop' in partition.device:
                        continue

                    usage = psutil.disk_usage(partition.mountpoint)

                    metrics = {
                        'timestamp': timestamp,
                        'device': partition.device,
                        'mountpoint': partition.mountpoint,
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': usage.percent
                    }

                    disk_metrics.append(metrics)
                    self.logger.debug(
                        f"Collected disk metrics for {partition.mountpoint}: {usage.percent}% used"
                    )

                except PermissionError:
                    self.logger.warning(f"Permission denied accessing {partition.mountpoint}")
                except Exception as e:
                    self.logger.warning(f"Error collecting metrics for {partition.mountpoint}: {e}")

            return disk_metrics

        except Exception as e:
            self.logger.error(f"Error collecting disk metrics: {e}")
            raise

    def collect_temperature_metrics(self) -> List[Dict]:
        """Collect temperature sensor metrics if available.

        Returns:
            List of dictionaries containing temperature metrics
        """
        try:
            timestamp = datetime.now().isoformat()
            temp_metrics = []

            # Try to get temperature sensors
            try:
                temps = psutil.sensors_temperatures()
                if temps:
                    for sensor_name, entries in temps.items():
                        for entry in entries:
                            metrics = {
                                'timestamp': timestamp,
                                'sensor_name': sensor_name,
                                'label': entry.label or 'unknown',
                                'current': entry.current,
                                'high': entry.high if entry.high else None,
                                'critical': entry.critical if entry.critical else None
                            }
                            temp_metrics.append(metrics)
                            self.logger.debug(
                                f"Temperature {sensor_name}/{entry.label}: {entry.current}°C"
                            )
                else:
                    self.logger.debug("No temperature sensors found")
            except AttributeError:
                self.logger.debug("Temperature sensors not supported on this platform")
            except Exception as e:
                self.logger.warning(f"Error reading temperature sensors: {e}")

            return temp_metrics

        except Exception as e:
            self.logger.error(f"Error collecting temperature metrics: {e}")
            return []

    def collect_gpu_metrics(self) -> List[Dict]:
        """Collect GPU utilization and metrics if available.

        Returns:
            List of dictionaries containing GPU metrics
        """
        try:
            timestamp = datetime.now().isoformat()
            gpu_metrics = []

            # NVIDIA GPUs
            if self.nvidia_initialized:
                try:
                    for i in range(self.gpu_count):
                        handle = pynvml.nvmlDeviceGetHandleByIndex(i)

                        # Get GPU name
                        name = pynvml.nvmlDeviceGetName(handle)
                        if isinstance(name, bytes):
                            name = name.decode('utf-8')

                        # Get utilization
                        utilization = pynvml.nvmlDeviceGetUtilizationRates(handle)

                        # Get memory info
                        memory = pynvml.nvmlDeviceGetMemoryInfo(handle)

                        # Get temperature
                        try:
                            temperature = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
                        except:
                            temperature = None

                        # Get power usage
                        try:
                            power = pynvml.nvmlDeviceGetPowerUsage(handle) / 1000.0  # Convert mW to W
                        except:
                            power = None

                        # Get power limit
                        try:
                            power_limit = pynvml.nvmlDeviceGetPowerManagementLimit(handle) / 1000.0
                        except:
                            power_limit = None

                        # Get fan speed
                        try:
                            fan_speed = pynvml.nvmlDeviceGetFanSpeed(handle)
                        except:
                            fan_speed = None

                        metrics = {
                            'timestamp': timestamp,
                            'gpu_index': i,
                            'gpu_name': name,
                            'gpu_utilization': utilization.gpu,
                            'memory_utilization': utilization.memory,
                            'memory_total': memory.total,
                            'memory_used': memory.used,
                            'memory_free': memory.free,
                            'temperature': temperature,
                            'power_draw': power,
                            'power_limit': power_limit,
                            'fan_speed': fan_speed
                        }

                        gpu_metrics.append(metrics)
                        self.logger.debug(
                            f"GPU {i} ({name}): {utilization.gpu}% utilization, "
                            f"{memory.used / memory.total * 100:.1f}% memory, {temperature}°C"
                        )

                except Exception as e:
                    self.logger.warning(f"Error reading NVIDIA GPU metrics: {e}")

            return gpu_metrics

        except Exception as e:
            self.logger.error(f"Error collecting GPU metrics: {e}")
            return []

    def get_system_info(self) -> Dict:
        """Get static system information.

        Returns:
            Dictionary containing system information
        """
        try:
            info = {
                'hostname': psutil.os.uname().nodename if hasattr(psutil.os, 'uname') else 'unknown',
                'cpu_count': psutil.cpu_count(logical=False),
                'cpu_count_logical': psutil.cpu_count(logical=True),
                'total_memory': psutil.virtual_memory().total,
                'boot_time': datetime.fromtimestamp(psutil.boot_time()).isoformat(),
                'gpu_count': self.gpu_count if self.nvidia_initialized else 0
            }
            return info
        except Exception as e:
            self.logger.error(f"Error collecting system info: {e}")
            return {}

    def __del__(self):
        """Cleanup GPU monitoring on destruction."""
        if self.nvidia_initialized:
            try:
                pynvml.nvmlShutdown()
            except:
                pass
