"""
alert_manager.py
================
Alert dispatching for the Energy Grid Monitor.

Supports multiple notification channels (email, webhook, SMS gateway).
Channels are configured via config.yaml under the ``alerts`` key.
"""

from __future__ import annotations

import json
import logging
import smtplib
from email.mime.text import MIMEText
from typing import Any

import requests

from .models import AlertSeverity, GridReading

logger = logging.getLogger(__name__)

# Timeout in seconds for outbound webhook calls
_WEBHOOK_TIMEOUT = 5


class AlertManager:
    """Dispatch grid alerts to one or more notification channels.

    Args:
        config: Loaded configuration dict (``alerts`` section used).
    """

    def __init__(self, config: dict[str, Any]) -> None:
        self._cfg = config.get("alerts", {})

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def dispatch(self, reading: GridReading, issues: list[str]) -> None:
        """Send an alert for a grid reading that breached thresholds.

        Args:
            reading: The offending sensor reading.
            issues:  Human-readable descriptions of each threshold breach.
        """
        severity = self._classify(reading, issues)
        message = self._format_message(reading, issues, severity)
        logger.warning("ALERT [%s] node=%s — %s", severity.value, reading.node_id, "; ".join(issues))

        if self._cfg.get("email", {}).get("enabled"):
            self._send_email(message, severity)
        if self._cfg.get("webhook", {}).get("enabled"):
            self._send_webhook(reading, issues, severity)

    # ------------------------------------------------------------------
    # Severity classification
    # ------------------------------------------------------------------

    def _classify(self, reading: GridReading, issues: list[str]) -> AlertSeverity:
        """Determine alert severity based on load level and issue count.

        Args:
            reading: Sensor reading that triggered the alert.
            issues:  List of threshold breach descriptions.

        Returns:
            :class:`AlertSeverity` enum value.
        """
        if reading.load_pct >= 98.0 or len(issues) >= 3:
            return AlertSeverity.CRITICAL
        if reading.load_pct >= 90.0 or len(issues) >= 2:
            return AlertSeverity.HIGH
        return AlertSeverity.MEDIUM

    # ------------------------------------------------------------------
    # Channel implementations
    # ------------------------------------------------------------------

    def _send_email(self, message: str, severity: AlertSeverity) -> None:
        """Send alert via SMTP.

        Args:
            message:  Formatted alert body.
            severity: Alert severity for the subject line.
        """
        email_cfg = self._cfg.get("email", {})
        try:
            msg = MIMEText(message)
            msg["Subject"] = f"[{severity.value}] Grid Alert — Energy Grid Monitor"
            msg["From"] = email_cfg["from"]
            msg["To"] = ", ".join(email_cfg["recipients"])

            with smtplib.SMTP(email_cfg["smtp_host"], email_cfg.get("smtp_port", 587)) as server:
                server.starttls()
                server.login(email_cfg["username"], email_cfg["password"])
                server.sendmail(email_cfg["from"], email_cfg["recipients"], msg.as_string())
            logger.info("Alert email sent to %s", email_cfg["recipients"])
        except Exception:
            logger.exception("Failed to send alert email")

    def _send_webhook(
        self, reading: GridReading, issues: list[str], severity: AlertSeverity
    ) -> None:
        """POST alert payload to a webhook URL.

        Args:
            reading:  Sensor reading that triggered the alert.
            issues:   List of threshold breach descriptions.
            severity: Alert severity.
        """
        webhook_cfg = self._cfg.get("webhook", {})
        payload = {
            "node_id": reading.node_id,
            "timestamp": reading.timestamp.isoformat(),
            "severity": severity.value,
            "issues": issues,
            "voltage_kv": reading.voltage_kv,
            "load_pct": reading.load_pct,
            "frequency_hz": reading.frequency_hz,
        }
        try:
            response = requests.post(
                webhook_cfg["url"],
                json=payload,
                timeout=_WEBHOOK_TIMEOUT,
                headers={"Content-Type": "application/json"},
            )
            response.raise_for_status()
            logger.info("Webhook alert dispatched — status %d", response.status_code)
        except Exception:
            logger.exception("Failed to dispatch webhook alert")

    # ------------------------------------------------------------------
    # Formatting
    # ------------------------------------------------------------------

    @staticmethod
    def _format_message(reading: GridReading, issues: list[str], severity: AlertSeverity) -> str:
        """Build a plain-text alert message body.

        Args:
            reading:  Sensor reading details.
            issues:   List of breach descriptions.
            severity: Alert severity level.

        Returns:
            Formatted string ready for email or log output.
        """
        lines = [
            f"Grid Alert — Severity: {severity.value}",
            f"Node     : {reading.node_id}",
            f"Timestamp: {reading.timestamp.isoformat()}",
            f"Voltage  : {reading.voltage_kv:.2f} kV",
            f"Load     : {reading.load_pct:.1f}%",
            f"Frequency: {reading.frequency_hz:.3f} Hz",
            "",
            "Issues detected:",
        ]
        lines += [f"  • {issue}" for issue in issues]
        return "\n".join(lines)
