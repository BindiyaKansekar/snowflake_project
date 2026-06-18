import unittest
from datetime import datetime, timezone
from unittest.mock import Mock

from src.grid_monitor import GridMonitor
from src.models import GridReading


class GridMonitorTests(unittest.TestCase):
    def test_frequency_deviation_triggers_alert(self):
        config = {
            "monitor": {"poll_interval_seconds": 1},
            "thresholds": {"frequency_deviation_hz": 0.5, "load_capacity_pct": 90.0, "voltage_variance_pct": 5.0},
            "nodes": [
                {
                    "id": "node-substation-north",
                    "endpoint": "192.168.10.11",
                    "nominal_voltage_kv": 132.0,
                    "nominal_frequency_hz": 50.0,
                    "region": "north",
                }
            ],
        }
        alert_manager = Mock()
        monitor = GridMonitor(config, alert_manager)

        reading = GridReading(
            node_id="node-substation-north",
            timestamp=datetime.now(timezone.utc),
            voltage_kv=132.0,
            load_pct=45.0,
            frequency_hz=51.2,
        )

        monitor._evaluate(reading)

        alert_manager.dispatch.assert_called_once()
        issues = alert_manager.dispatch.call_args[0][1]
        self.assertTrue(any("Frequency deviation" in issue for issue in issues))

    def test_build_sensor_node_supports_id_alias(self):
        config_node = {
            "id": "node-distribution-east",
            "endpoint": "192.168.10.21",
            "nominal_voltage_kv": 11.0,
            "nominal_frequency_hz": 50.0,
            "region": "east",
        }
        monitor = GridMonitor({"monitor": {}, "thresholds": {}}, Mock())
        node = monitor._build_sensor_node(config_node)

        self.assertEqual(node.node_id, "node-distribution-east")
        self.assertEqual(node.endpoint, "192.168.10.21")
        self.assertEqual(node.nominal_voltage_kv, 11.0)
        self.assertEqual(node.nominal_frequency_hz, 50.0)


if __name__ == "__main__":
    unittest.main()
