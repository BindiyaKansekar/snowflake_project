"""
models.py
=========
Domain models for the Energy Grid Monitor system.

All models use dataclasses for lightweight, typed representations of
sensor telemetry, grid status, and alert severity.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class GridStatus(str, Enum):
    """Operational status of a grid node."""
    NOMINAL = "NOMINAL"
    WARNING = "WARNING"
    FAULT = "FAULT"
    OFFLINE = "OFFLINE"


class AlertSeverity(str, Enum):
    """Severity level for grid alerts."""
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


@dataclass
class SensorNode:
    """Metadata for a physical sensor node on the grid.

    Attributes:
        node_id:            Unique identifier for this sensor node.
        endpoint:           Network endpoint (IP/hostname) for SCADA queries.
        nominal_voltage_kv: Expected operating voltage in kilovolts.
        region:             Geographic or operational region label.
        nominal_frequency_hz: Expected nominal frequency for this node in Hz.
    """
    node_id: str
    endpoint: str
    nominal_voltage_kv: float
    nominal_frequency_hz: float = 50.0
    nominal_frequency_hz: float = 50.0
    region: str = "default"


@dataclass
class GridReading:
    """A single telemetry snapshot from a sensor node.

    Attributes:
        node_id:      Identifies the originating sensor node.
        timestamp:    UTC timestamp of the reading.
        voltage_kv:   Measured voltage in kilovolts.
        load_pct:     Current load as a percentage of rated capacity.
        frequency_hz: Grid frequency in hertz (nominal 50 Hz or 60 Hz).
        status:       Evaluated grid status at the time of reading.
    """
    node_id: str
    timestamp: datetime
    voltage_kv: float
    load_pct: float
    frequency_hz: float
    status: GridStatus = GridStatus.NOMINAL


@dataclass
class OutageEvent:
    """Represents a confirmed grid outage event.

    Attributes:
        event_id:       Unique identifier for this outage.
        node_id:        Affected sensor node.
        start_time:     UTC time when the outage was first detected.
        end_time:       UTC time when the outage was resolved, or None if ongoing.
        affected_areas: List of region/area labels impacted.
        cause:          Root cause description (populated post-investigation).
    """
    event_id: str
    node_id: str
    start_time: datetime
    end_time: datetime | None = None
    affected_areas: list[str] = field(default_factory=list)
    cause: str = "Under investigation"

    @property
    def is_active(self) -> bool:
        """Return True if the outage is still ongoing."""
        return self.end_time is None
