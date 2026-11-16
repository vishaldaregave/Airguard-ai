"""
AIRGUARD AI — Operational Monitoring Service for Alerts & Notifications
Provides real-time visibility into alert evaluations, ingestion recency,
delivery statistics, invalid device tokens, and worker health.
Strict Security: Never exposes tokens or secrets.
"""

from __future__ import annotations

import threading
from datetime import datetime, timezone
from typing import Any, Dict, Optional


class AlertMonitoringService:
    """
    Thread-safe operational telemetry tracker for the alert and notification subsystem.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.last_evaluation_timestamp: Optional[datetime] = None
        self.last_environmental_data_ingestion: Optional[datetime] = None
        self.last_evaluated_station: Optional[str] = None
        self.evaluations_total_count: int = 0
        self.alerts_triggered_count: int = 0
        self.pending_notifications_count: int = 0
        self.successful_deliveries_count: int = 0
        self.failed_deliveries_count: int = 0
        self.invalid_device_tokens_count: int = 0
        self.idempotent_skips_count: int = 0
        self.worker_health: str = "HEALTHY"  # HEALTHY, DEGRADED, ERROR, IDLE
        self.last_error: Optional[str] = None
        self.last_error_timestamp: Optional[datetime] = None

    def record_ingestion(self, station_code: str, timestamp: Optional[datetime] = None) -> None:
        """Records telemetry ingestion event."""
        with self._lock:
            self.last_environmental_data_ingestion = timestamp or datetime.now(timezone.utc)
            self.last_evaluated_station = station_code

    def record_evaluation(
        self,
        station_code: str,
        alerts_count: int,
        subscribers_count: int = 1,
        evaluation_timestamp: Optional[datetime] = None,
    ) -> None:
        """Records a completed evaluation cycle."""
        with self._lock:
            self.last_evaluation_timestamp = evaluation_timestamp or datetime.now(timezone.utc)
            self.last_evaluated_station = station_code
            self.evaluations_total_count += 1
            self.alerts_triggered_count += alerts_count
            self.worker_health = "HEALTHY"

    def record_idempotent_skip(self, station_code: str) -> None:
        """Records an evaluation skipped due to idempotent observation deduplication."""
        with self._lock:
            self.idempotent_skips_count += 1

    def record_delivery(
        self,
        success_count: int,
        failure_count: int,
        is_mock: bool = False,
    ) -> None:
        """Records push notification delivery outcome."""
        with self._lock:
            self.successful_deliveries_count += success_count
            self.failed_deliveries_count += failure_count

    def record_invalid_token(self) -> None:
        """Records an invalid / unregistered device token detected during delivery."""
        with self._lock:
            self.invalid_device_tokens_count += 1

    def record_error(self, error_message: str) -> None:
        """Records an operational worker error."""
        with self._lock:
            self.last_error = error_message
            self.last_error_timestamp = datetime.now(timezone.utc)
            self.worker_health = "DEGRADED"

    def get_status(self) -> Dict[str, Any]:
        """Returns snapshot of operational health metrics without exposing secrets."""
        with self._lock:
            return {
                "worker_health": self.worker_health,
                "evaluations_total_count": self.evaluations_total_count,
                "alerts_triggered_count": self.alerts_triggered_count,
                "idempotent_skips_count": self.idempotent_skips_count,
                "pending_notifications_count": self.pending_notifications_count,
                "successful_deliveries_count": self.successful_deliveries_count,
                "failed_deliveries_count": self.failed_deliveries_count,
                "invalid_device_tokens_count": self.invalid_device_tokens_count,
                "last_evaluated_station": self.last_evaluated_station,
                "last_evaluation_timestamp": (
                    self.last_evaluation_timestamp.isoformat()
                    if self.last_evaluation_timestamp
                    else None
                ),
                "last_environmental_data_ingestion": (
                    self.last_environmental_data_ingestion.isoformat()
                    if self.last_environmental_data_ingestion
                    else None
                ),
                "last_error": self.last_error,
                "last_error_timestamp": (
                    self.last_error_timestamp.isoformat()
                    if self.last_error_timestamp
                    else None
                ),
            }


alert_monitor = AlertMonitoringService()
