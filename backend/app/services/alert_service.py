"""
AIRGUARD AI — Alert Service
Orchestrates user preferences, alert state tracking, deterministic engine evaluation,
FCM dispatch, and alert history persistence.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.core.config import settings
from app.db.models import (
    UserAlertPreference,
    DeviceToken,
    AlertRecord,
    AlertStateTracker,
)
from app.schemas.alert import (
    UserAlertPreferenceInput,
    UserAlertPreferenceResponse,
    AlertItem,
)
from app.schemas.pollutant import EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult
from app.schemas.forecast import ForecastCurrentResponse
from app.engine.alert_engine import alert_engine, AlertCandidate
from app.services.fcm_service import fcm_service
from app.services.alert_monitor import alert_monitor
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


class AlertService:
    """Manages environmental alerts, user preferences, and notification lifecycles."""

    def get_or_create_user_preferences(self, db: Session, user_id: str) -> UserAlertPreference:
        """Fetch user alert preferences, creating default settings if not yet existing."""
        pref = db.query(UserAlertPreference).filter(UserAlertPreference.user_id == user_id).first()
        if not pref:
            pref = UserAlertPreference(
                user_id=user_id,
                notifications_enabled=True,
                aqi_threshold=settings.ALERT_DEFAULT_AQI_THRESHOLD,
                pm25_threshold=settings.ALERT_DEFAULT_PM25_THRESHOLD,
                pm10_threshold=settings.ALERT_DEFAULT_PM10_THRESHOLD,
                sudden_deterioration_enabled=True,
                forecast_alerts_enabled=True,
                recovery_alerts_enabled=True,
                quiet_hours_enabled=False,
                quiet_hours_start=22,
                quiet_hours_end=7,
                preferred_station_code=None,
                preferred_station_name=None,
            )
            db.add(pref)
            db.commit()
            db.refresh(pref)
        return pref

    def update_user_preferences(
        self,
        db: Session,
        user_id: str,
        input_data: UserAlertPreferenceInput,
    ) -> UserAlertPreference:
        """Update and persist user alert preferences."""
        pref = self.get_or_create_user_preferences(db, user_id)
        
        pref.notifications_enabled = input_data.notifications_enabled
        pref.aqi_threshold = input_data.aqi_threshold
        pref.pm25_threshold = input_data.pm25_threshold
        pref.pm10_threshold = input_data.pm10_threshold
        pref.sudden_deterioration_enabled = input_data.sudden_deterioration_enabled
        pref.forecast_alerts_enabled = input_data.forecast_alerts_enabled
        pref.recovery_alerts_enabled = input_data.recovery_alerts_enabled
        pref.quiet_hours_enabled = input_data.quiet_hours_enabled
        pref.quiet_hours_start = input_data.quiet_hours_start
        pref.quiet_hours_end = input_data.quiet_hours_end
        pref.preferred_station_code = input_data.preferred_station_code
        pref.preferred_station_name = input_data.preferred_station_name
        pref.updated_at = datetime.now(timezone.utc)

        db.commit()
        db.refresh(pref)
        return pref

    def register_device_token(
        self,
        db: Session,
        user_id: str,
        token: str,
        device_type: str = "android",
    ) -> DeviceToken:
        """Register or refresh an FCM device registration token for a user."""
        record = db.query(DeviceToken).filter(DeviceToken.token == token).first()
        if record:
            record.user_id = user_id
            record.device_type = device_type
            record.is_active = True
            record.updated_at = datetime.now(timezone.utc)
        else:
            record = DeviceToken(
                user_id=user_id,
                token=token,
                device_type=device_type,
                is_active=True,
            )
            db.add(record)
        db.commit()
        db.refresh(record)
        return record

    def unregister_device_token(self, db: Session, user_id: str, token: str) -> bool:
        """Deactivate or remove a device registration token."""
        record = db.query(DeviceToken).filter(
            DeviceToken.user_id == user_id,
            DeviceToken.token == token,
            DeviceToken.is_active.is_(True),
        ).first()
        if record:
            record.is_active = False
            record.updated_at = datetime.now(timezone.utc)
            db.commit()
            return True
        return False


    def refresh_device_token(
        self,
        db: Session,
        user_id: str,
        old_token: str,
        new_token: str,
        device_type: str = "android",
    ) -> DeviceToken:
        """Rotate FCM device registration token for authenticated user."""
        old_record = db.query(DeviceToken).filter(
            DeviceToken.token == old_token,
            DeviceToken.user_id == user_id,
        ).first()

        if not old_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Original device token not found for this user",
            )

        old_record.is_active = False
        old_record.updated_at = datetime.now(timezone.utc)

        new_record = db.query(DeviceToken).filter(DeviceToken.token == new_token).first()
        if new_record:
            new_record.user_id = user_id
            new_record.device_type = device_type
            new_record.is_active = True
            new_record.updated_at = datetime.now(timezone.utc)
        else:
            new_record = DeviceToken(
                user_id=user_id,
                token=new_token,
                device_type=device_type,
                is_active=True,
            )
            db.add(new_record)

        db.commit()
        db.refresh(new_record)
        return new_record

    def get_active_tokens_for_user(self, db: Session, user_id: str) -> List[str]:
        """Fetch all active FCM device tokens for a given user."""
        records = db.query(DeviceToken).filter(
            DeviceToken.user_id == user_id,
            DeviceToken.is_active.is_(True),
        ).all()
        return [r.token for r in records]

    def list_alerts(
        self,
        db: Session,
        user_id: str,
        limit: int = 50,
        offset: int = 0,
        unread_only: bool = False,
        severity: Optional[str] = None,
    ) -> Tuple[List[AlertRecord], int, int]:
        """List persisted alerts for a user with total count and unread count."""
        query = db.query(AlertRecord).filter(AlertRecord.user_id == user_id)
        
        unread_count = db.query(AlertRecord).filter(
            AlertRecord.user_id == user_id,
            AlertRecord.is_read.is_(False),
        ).count()

        if unread_only:
            query = query.filter(AlertRecord.is_read.is_(False))
        if severity:
            query = query.filter(AlertRecord.severity == severity.upper())

        total = query.count()
        records = query.order_by(desc(AlertRecord.created_at)).offset(offset).limit(limit).all()
        return records, total, unread_count

    def mark_alert_read(self, db: Session, user_id: str, alert_id: str) -> Optional[AlertRecord]:
        """Mark an alert record as read for the authorized user."""
        record = db.query(AlertRecord).filter(
            AlertRecord.alert_id == alert_id,
            AlertRecord.user_id == user_id,
        ).first()
        if record:
            record.is_read = True
            db.commit()
            db.refresh(record)
            return record
        return None

    def evaluate_and_dispatch_observation(
        self,
        db: Session,
        user_id: str,
        obs: EnvironmentalObservationInput,
        aqi_result: Optional[AQICalculationResult] = None,
    ) -> List[AlertItem]:
        """
        Evaluate an observation against user preferences, apply smart filtering,
        persist alerts, and dispatch notifications via FCM.
        """
        pref_model = self.get_or_create_user_preferences(db, user_id)
        pref_schema = UserAlertPreferenceResponse(
            user_id=pref_model.user_id,
            notifications_enabled=pref_model.notifications_enabled,
            aqi_threshold=pref_model.aqi_threshold,
            pm25_threshold=pref_model.pm25_threshold,
            pm10_threshold=pref_model.pm10_threshold,
            sudden_deterioration_enabled=pref_model.sudden_deterioration_enabled,
            forecast_alerts_enabled=pref_model.forecast_alerts_enabled,
            recovery_alerts_enabled=pref_model.recovery_alerts_enabled,
            quiet_hours_enabled=pref_model.quiet_hours_enabled,
            quiet_hours_start=pref_model.quiet_hours_start,
            quiet_hours_end=pref_model.quiet_hours_end,
            preferred_station_code=pref_model.preferred_station_code,
            preferred_station_name=pref_model.preferred_station_name,
            updated_at=pref_model.updated_at,
        )

        if not pref_schema.notifications_enabled:
            return []

        station_code = obs.station_id or f"GRID-{obs.location.latitude:.2f}-{obs.location.longitude:.2f}"
        if pref_schema.preferred_station_code and pref_schema.preferred_station_code != station_code:
            logger.debug(
                "Skipping alert evaluation for station %s (user prefers %s)",
                station_code,
                pref_schema.preferred_station_code,
            )
            return []

        # Query all existing state trackers for this user and station
        trackers = db.query(AlertStateTracker).filter(
            AlertStateTracker.user_id == user_id,
            AlertStateTracker.station_code == station_code,
        ).all()
        tracker_map = {t.alert_type: t for t in trackers}

        active_tracker_dict = None
        aqi_tracker = tracker_map.get("AQI_THRESHOLD")
        if aqi_tracker:
            active_tracker_dict = {
                "is_in_alert": aqi_tracker.is_active,
                "last_observed_value": aqi_tracker.last_observed_value,
                "last_severity": aqi_tracker.last_severity,
                "last_alert_time": aqi_tracker.last_triggered_at,
            }

        # Generate candidate alerts deterministically
        candidates = alert_engine.evaluate_observation(
            obs=obs,
            aqi_result=aqi_result,
            pref=pref_schema,
            previous_obs=None,
            active_tracker=active_tracker_dict,
        )

        dispatched_alerts: List[AlertItem] = []
        active_tokens = self.get_active_tokens_for_user(db, user_id)

        for candidate in candidates:
            tracker = tracker_map.get(candidate.alert_type.value)
            tracker_info = None
            if tracker:
                tracker_info = {
                    "is_in_alert": tracker.is_active,
                    "last_alert_time": tracker.last_triggered_at,
                    "last_observed_value": tracker.last_observed_value,
                    "last_severity": tracker.last_severity,
                }

            should_send, reason = alert_engine.should_dispatch_alert(
                candidate=candidate,
                pref=pref_schema,
                active_tracker=tracker_info,
            )

            if not should_send:
                logger.debug("Alert suppressed: %s (%s)", candidate.alert_type.value, reason)
                continue

            if reason == "QUIET_HOURS_SUPPRESSED":
                delivery_status = "QUIET_HOURS_SUPPRESSED"
            else:
                fcm_result = fcm_service.send_multicast(
                    tokens=active_tokens,
                    title=f"AIRGUARD: {candidate.severity.value} Alert - {candidate.station_name}",
                    body=f"{candidate.trigger_reason} Rec: {candidate.recommended_precaution}",
                    data={
                        "alert_id": candidate.alert_id,
                        "alert_type": candidate.alert_type.value,
                        "severity": candidate.severity.value,
                        "station_code": candidate.station_code,
                        "observed_value": str(candidate.observed_value),
                    },
                )
                delivery_status = fcm_result.delivery_status
                alert_monitor.record_delivery(
                    success_count=fcm_result.success_count,
                    failure_count=fcm_result.failure_count,
                )
                for detail in fcm_result.details:
                    err_str = str(detail.get("error", "")).lower()
                    if any(w in err_str for w in ["not registered", "invalid", "unregistered"]):
                        alert_monitor.record_invalid_token()

            # Persist AlertRecord
            record = AlertRecord(
                alert_id=candidate.alert_id,
                user_id=user_id,
                alert_type=candidate.alert_type.value,
                severity=candidate.severity.value,
                station_code=candidate.station_code,
                station_name=candidate.station_name,
                pollutant=candidate.pollutant,
                observed_value=candidate.observed_value,
                threshold_value=candidate.threshold_value,
                unit=candidate.unit,
                source_provenance=candidate.source_provenance,
                observation_timestamp=candidate.observation_timestamp,
                trigger_reason=candidate.trigger_reason,
                recommended_precaution=candidate.recommended_precaution,
                is_forecast=candidate.is_forecast,
                forecast_horizon_hours=candidate.forecast_horizon_hours,
                is_read=False,
                is_resolved=candidate.is_recovery,
                delivery_status=delivery_status,
            )
            db.add(record)

            # Update or create AlertStateTracker
            if not tracker:
                tracker = AlertStateTracker(
                    user_id=user_id,
                    station_code=candidate.station_code,
                    alert_type=candidate.alert_type.value,
                    last_alert_id=candidate.alert_id,
                    last_triggered_at=datetime.now(timezone.utc),
                    last_observed_value=candidate.observed_value,
                    last_severity=candidate.severity.value,
                    is_active=not candidate.is_recovery,
                )
                db.add(tracker)
                tracker_map[candidate.alert_type.value] = tracker
            else:
                tracker.last_alert_id = candidate.alert_id
                tracker.last_triggered_at = datetime.now(timezone.utc)
                tracker.last_observed_value = candidate.observed_value
                tracker.last_severity = candidate.severity.value
                tracker.is_active = not candidate.is_recovery
                tracker.updated_at = datetime.now(timezone.utc)

            db.commit()
            db.refresh(record)

            dispatched_alerts.append(
                AlertItem(
                    alert_id=record.alert_id,
                    user_id=record.user_id,
                    alert_type=candidate.alert_type,
                    severity=candidate.severity,
                    station_code=record.station_code,
                    station_name=record.station_name,
                    pollutant=record.pollutant,
                    observed_value=record.observed_value,
                    threshold_value=record.threshold_value,
                    unit=record.unit,
                    source_provenance=record.source_provenance,
                    observation_timestamp=record.observation_timestamp,
                    trigger_reason=record.trigger_reason,
                    recommended_precaution=record.recommended_precaution,
                    is_forecast=record.is_forecast,
                    forecast_horizon_hours=record.forecast_horizon_hours,
                    is_read=record.is_read,
                    is_resolved=record.is_resolved,
                    delivery_status=record.delivery_status,
                    created_at=record.created_at,
                )
            )

        return dispatched_alerts

    def evaluate_and_dispatch_forecast(
        self,
        db: Session,
        user_id: str,
        forecast: ForecastCurrentResponse,
    ) -> List[AlertItem]:
        """
        Evaluate forecast predictions against user preferences, apply smart filtering,
        persist alerts, and dispatch notifications via FCM.
        """
        pref_model = self.get_or_create_user_preferences(db, user_id)
        pref_schema = UserAlertPreferenceResponse(
            user_id=pref_model.user_id,
            notifications_enabled=pref_model.notifications_enabled,
            aqi_threshold=pref_model.aqi_threshold,
            pm25_threshold=pref_model.pm25_threshold,
            pm10_threshold=pref_model.pm10_threshold,
            sudden_deterioration_enabled=pref_model.sudden_deterioration_enabled,
            forecast_alerts_enabled=pref_model.forecast_alerts_enabled,
            recovery_alerts_enabled=pref_model.recovery_alerts_enabled,
            quiet_hours_enabled=pref_model.quiet_hours_enabled,
            quiet_hours_start=pref_model.quiet_hours_start,
            quiet_hours_end=pref_model.quiet_hours_end,
            preferred_station_code=pref_model.preferred_station_code,
            preferred_station_name=pref_model.preferred_station_name,
            updated_at=pref_model.updated_at,
        )

        if not pref_schema.notifications_enabled or not pref_schema.forecast_alerts_enabled:
            return []

        if pref_schema.preferred_station_code and pref_schema.preferred_station_code != forecast.station_id:
            return []

        tracker = db.query(AlertStateTracker).filter(
            AlertStateTracker.user_id == user_id,
            AlertStateTracker.station_code == forecast.station_id,
            AlertStateTracker.alert_type == "FORECAST_WARNING",
        ).first()

        tracker_info = None
        if tracker:
            tracker_info = {
                "is_in_alert": tracker.is_active,
                "last_alert_time": tracker.last_triggered_at,
                "last_observed_value": tracker.last_observed_value,
                "last_severity": tracker.last_severity,
            }

        candidates = alert_engine.evaluate_forecast(
            forecast=forecast,
            pref=pref_schema,
            active_tracker=tracker_info,
        )

        dispatched_alerts: List[AlertItem] = []
        active_tokens = self.get_active_tokens_for_user(db, user_id)

        for candidate in candidates:
            should_send, reason = alert_engine.should_dispatch_alert(
                candidate=candidate,
                pref=pref_schema,
                active_tracker=tracker_info,
            )
            if not should_send:
                continue

            fcm_result = fcm_service.send_multicast(
                tokens=active_tokens,
                title=f"AIRGUARD Warning: High Pollution Expected ({forecast.station_name})",
                body=f"{candidate.trigger_reason} Rec: {candidate.recommended_precaution}",
                data={
                    "alert_id": candidate.alert_id,
                    "alert_type": candidate.alert_type.value,
                    "severity": candidate.severity.value,
                    "station_code": candidate.station_code,
                    "observed_value": str(candidate.observed_value),
                    "is_forecast": "true",
                },
            )

            record = AlertRecord(
                alert_id=candidate.alert_id,
                user_id=user_id,
                alert_type=candidate.alert_type.value,
                severity=candidate.severity.value,
                station_code=candidate.station_code,
                station_name=candidate.station_name,
                pollutant=candidate.pollutant,
                observed_value=candidate.observed_value,
                threshold_value=candidate.threshold_value,
                unit=candidate.unit,
                source_provenance=candidate.source_provenance,
                observation_timestamp=candidate.observation_timestamp,
                trigger_reason=candidate.trigger_reason,
                recommended_precaution=candidate.recommended_precaution,
                is_forecast=True,
                forecast_horizon_hours=candidate.forecast_horizon_hours,
                is_read=False,
                is_resolved=False,
                delivery_status=fcm_result.delivery_status,
            )
            db.add(record)

            if not tracker:
                tracker = AlertStateTracker(
                    user_id=user_id,
                    station_code=candidate.station_code,
                    alert_type="FORECAST_WARNING",
                    last_alert_id=candidate.alert_id,
                    last_triggered_at=datetime.now(timezone.utc),
                    last_observed_value=candidate.observed_value,
                    last_severity=candidate.severity.value,
                    is_active=True,
                )
                db.add(tracker)
            else:
                tracker.last_alert_id = candidate.alert_id
                tracker.last_triggered_at = datetime.now(timezone.utc)
                tracker.last_observed_value = candidate.observed_value
                tracker.last_severity = candidate.severity.value
                tracker.is_active = True
                tracker.updated_at = datetime.now(timezone.utc)

            db.commit()
            db.refresh(record)

            dispatched_alerts.append(
                AlertItem(
                    alert_id=record.alert_id,
                    user_id=record.user_id,
                    alert_type=candidate.alert_type,
                    severity=candidate.severity,
                    station_code=record.station_code,
                    station_name=record.station_name,
                    pollutant=record.pollutant,
                    observed_value=record.observed_value,
                    threshold_value=record.threshold_value,
                    unit=record.unit,
                    source_provenance=record.source_provenance,
                    observation_timestamp=record.observation_timestamp,
                    trigger_reason=record.trigger_reason,
                    recommended_precaution=record.recommended_precaution,
                    is_forecast=True,
                    forecast_horizon_hours=record.forecast_horizon_hours,
                    is_read=record.is_read,
                    is_resolved=record.is_resolved,
                    delivery_status=record.delivery_status,
                    created_at=record.created_at,
                )
            )

        return dispatched_alerts


alert_service = AlertService()
