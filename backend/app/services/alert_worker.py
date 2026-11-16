"""
AIRGUARD AI — Automatic Background Alert Evaluation Worker
Evaluates new environmental observations against all active user subscriptions.
Ensures:
- Strictly deterministic evaluation (no LLMs in decision path).
- Idempotent processing (duplicate observation hashes are skipped).
- Persistent state tracking across worker restarts.
- Non-blocking execution so environmental ingestion APIs remain responsive.
- Real-time operational telemetry and health tracking.
"""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from app.db.base import SessionLocal
from app.db.models import EvaluatedObservationLog, UserAlertPreference
from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult
from app.schemas.alert import AlertItem
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.services.alert_service import alert_service
from app.services.alert_monitor import alert_monitor

logger = logging.getLogger(__name__)


def compute_observation_idempotency_hash(station_code: str, timestamp: datetime) -> str:
    """Computes a deterministic hash for station observation to enforce idempotency."""
    ts_str = timestamp.isoformat() if timestamp.tzinfo else timestamp.replace(tzinfo=timezone.utc).isoformat()
    raw = f"{station_code}:{ts_str}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


class AlertWorker:
    """
    Background evaluation engine coordinating multi-subscriber environmental alerts.
    """

    def evaluate_observation_for_subscribers(
        self,
        db: Session,
        obs: EnvironmentalObservationInput,
        aqi_result: Optional[AQICalculationResult] = None,
    ) -> List[AlertItem]:
        """
        Idempotently evaluates observation across all subscribed users.
        """
        station_code = obs.station_id or f"GRID-{obs.location.latitude:.2f}-{obs.location.longitude:.2f}"
        obs_time = obs.timestamp if obs.timestamp.tzinfo else obs.timestamp.replace(tzinfo=timezone.utc)

        # 1. Idempotency Check: Reject already-evaluated observations
        eval_hash = compute_observation_idempotency_hash(station_code, obs_time)
        existing_eval = db.query(EvaluatedObservationLog).filter(
            EvaluatedObservationLog.eval_hash == eval_hash
        ).first()

        if existing_eval:
            logger.debug(
                "AlertWorker: Skipping already-evaluated observation for station %s at %s (Hash: %s)",
                station_code,
                obs_time,
                eval_hash[:8],
            )
            alert_monitor.record_idempotent_skip(station_code)
            return []

        # Record ingestion event
        alert_monitor.record_ingestion(station_code, obs_time)

        # 2. Reject synthetic DEMO_FIXTURE or HISTORICAL data from live alert pipeline
        if obs.data_source_type in (DataSourceType.DEMO_FIXTURE, DataSourceType.HISTORICAL):
            logger.debug(
                "AlertWorker: Skipping non-live data source (%s) for station %s",
                obs.data_source_type.value,
                station_code,
            )
            return []

        # 3. Calculate CPCB AQI if not provided
        if aqi_result is None:
            aqi_result = calculate_cpcb_aqi(obs)

        # 4. Find all active user subscriptions eligible for this station
        # Users with notifications_enabled=True and (preferred_station is None or matches station_code)
        subscribers = db.query(UserAlertPreference).filter(
            UserAlertPreference.notifications_enabled.is_(True),
        ).all()

        matching_subscribers = [
            sub for sub in subscribers
            if sub.preferred_station_code is None
            or sub.preferred_station_code.strip() == ""
            or sub.preferred_station_code.strip() == station_code
        ]

        logger.info(
            "AlertWorker: Evaluating observation for %s against %d active subscriber(s)",
            station_code,
            len(matching_subscribers),
        )

        all_dispatched: List[AlertItem] = []

        # 5. Evaluate for each subscriber
        for subscriber in matching_subscribers:
            try:
                dispatched = alert_service.evaluate_and_dispatch_observation(
                    db=db,
                    user_id=subscriber.user_id,
                    obs=obs,
                    aqi_result=aqi_result,
                )
                all_dispatched.extend(dispatched)
            except Exception as e:
                logger.error(
                    "AlertWorker: Failed evaluating subscriber '%s': %s",
                    subscriber.user_id,
                    str(e),
                )
                alert_monitor.record_error(f"Subscriber {subscriber.user_id} evaluation failed: {str(e)}")

        # 6. Record idempotent evaluation log
        eval_log = EvaluatedObservationLog(
            eval_hash=eval_hash,
            station_code=station_code,
            observation_timestamp=obs_time,
            evaluated_at=datetime.now(timezone.utc),
            matched_subscriptions_count=len(matching_subscribers),
            dispatched_alerts_count=len(all_dispatched),
            data_source_type=obs.data_source_type.value,
        )
        db.add(eval_log)
        db.commit()

        # 7. Update operational monitoring
        alert_monitor.record_evaluation(
            station_code=station_code,
            alerts_count=len(all_dispatched),
            subscribers_count=len(matching_subscribers),
        )

        return all_dispatched


alert_worker = AlertWorker()


def trigger_background_alert_evaluation(obs: EnvironmentalObservationInput) -> None:
    """
    Non-blocking background task runner to evaluate new environmental telemetry.
    Catches exceptions safely so data ingestion APIs are never blocked.
    """
    db = SessionLocal()
    try:
        alert_worker.evaluate_observation_for_subscribers(db=db, obs=obs)
    except Exception as e:
        logger.error("Background alert evaluation failed: %s", str(e), exc_info=True)
        alert_monitor.record_error(f"Background task exception: {str(e)}")
    finally:
        db.close()
