"""
grid_monitor.py
===============
Core monitoring loop for the Energy Grid Monitor system.

Polls grid sensors at a configurable interval, evaluates threshold breaches,
and dispatches alerts via AlertManager when anomalies are detected.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

from .alert_manager import AlertManager
from .models import GridReading, GridStatus, SensorNode

logger = logging.getLogger(__name__)


class GridMonitor:
    """Continuously polls sensor nodes and evaluates grid health.

    Args:
        config:        Loaded configuration dict (from config.yaml).
        alert_manager: Injected AlertManager for dispatching notifications.
    """

    def __init__(self, config: dict[str, Any], alert_manager: AlertManager) -> None:
        self.config = config
        self.alert_manager = alert_manager
        self.poll_interval: int = config.get("monitor", {}).get("poll_interval_seconds", 30)
        self.voltage_threshold: float = config.get("thresholds", {}).get("voltage_variance_pct", 5.0)
        self.load_threshold: float = config.get("thresholds", {}).get("load_capacity_pct", 90.0)
        self.frequency_threshold: float = config.get("thresholds", {}).get("frequency_deviation_hz", 0.5)
        self._running: bool = False

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def start(self) -> None:
        """Start the monitoring loop. Runs until :meth:`stop` is called."""
        self._running = True
        logger.info("GridMonitor started — poll interval: %ds", self.poll_interval)
        while self._running:
            try:
                await self._poll_cycle()
            except Exception:
                logger.exception("Unhandled error in poll cycle — continuing")
            await asyncio.sleep(self.poll_interval)

    def stop(self) -> None:
        """Signal the monitoring loop to exit after the current cycle."""
        self._running = False
        logger.info("GridMonitor stop requested")

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _poll_cycle(self) -> None:
        """Execute one full poll cycle across all configured sensor nodes."""
        nodes: list[dict] = self.config.get("nodes", [])
        readings = await asyncio.gather(
            *[self._read_node(self._build_sensor_node(n)) for n in nodes],
            return_exceptions=True,
        )
        for node, result in zip(nodes, readings):
            if isinstance(result, Exception):
                logger.error("Failed to read node %s: %s", node.get("id") or node.get("node_id"), result)
                continue
            self._evaluate(result)

    async def _read_node(self, node: SensorNode) -> GridReading:
        """Fetch the latest telemetry from a single sensor node.

        Args:
            node: Sensor node metadata.

        Returns:
            A :class:`GridReading` with current voltage, load, and frequency.
        """
        # Placeholder: replace with actual SCADA/Modbus/IEC-61850 client call
        logger.debug("Reading node %s at %s", node.node_id, node.endpoint)
        return GridReading(
            node_id=node.node_id,
            timestamp=datetime.now(timezone.utc),
            voltage_kv=node.nominal_voltage_kv,
            load_pct=0.0,
            frequency_hz=node.nominal_frequency_hz,
            status=GridStatus.NOMINAL,
        )

    def _evaluate(self, reading: GridReading) -> None:
        """Evaluate a reading against configured thresholds and alert if needed.

        Args:
            reading: Latest telemetry from a sensor node.
        """
        issues: list[str] = []

        voltage_deviation = abs(reading.voltage_kv - self._nominal_voltage(reading.node_id))
        if voltage_deviation / max(self._nominal_voltage(reading.node_id), 1) * 100 > self.voltage_threshold:
            issues.append(
                f"Voltage deviation {voltage_deviation:.2f} kV exceeds {self.voltage_threshold}% threshold"
            )

        if reading.load_pct > self.load_threshold:
            issues.append(
                f"Load {reading.load_pct:.1f}% exceeds capacity threshold {self.load_threshold}%"
            )

        frequency_deviation = abs(reading.frequency_hz - self._nominal_frequency(reading.node_id))
        if frequency_deviation > self.frequency_threshold:
            issues.append(
                f"Frequency deviation {frequency_deviation:.3f} Hz exceeds {self.frequency_threshold:.3f} Hz threshold"
            )

        reading.status = GridStatus.WARNING if issues else GridStatus.NOMINAL

        if issues:
            self.alert_manager.dispatch(reading, issues)
        else:
            logger.debug("Node %s — all readings nominal", reading.node_id)

    def _nominal_voltage(self, node_id: str) -> float:
        """Return nominal voltage for a node from config.

        Args:
            node_id: Sensor node identifier.

        Returns:
            Nominal voltage in kV, defaulting to 11.0 kV if not found.
        """
        for node in self.config.get("nodes", []):
            if node.get("id") == node_id or node.get("node_id") == node_id:
                return float(node.get("nominal_voltage_kv", 11.0))
        return 11.0

    def _nominal_frequency(self, node_id: str) -> float:
        """Return nominal frequency for a node from config.

        Args:
            node_id: Sensor node identifier.

        Returns:
            Nominal frequency in Hz, defaulting to 50.0 Hz if not found.
        """
        for node in self.config.get("nodes", []):
            if node.get("id") == node_id or node.get("node_id") == node_id:
                return float(node.get("nominal_frequency_hz", 50.0))
        return 50.0

    def _build_sensor_node(self, config_node: dict[str, Any]) -> SensorNode:
        """Build a SensorNode from config data with backward-compatible id handling."""
        node_kwargs = {
            "node_id": config_node.get("node_id") or config_node.get("id"),
            "endpoint": config_node["endpoint"],
            "nominal_voltage_kv": float(config_node["nominal_voltage_kv"]),
            "nominal_frequency_hz": float(config_node.get("nominal_frequency_hz", 50.0)),
            "region": config_node.get("region", "default"),
        }
        return SensorNode(**node_kwargs)
