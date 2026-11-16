"""
AirGuard AI - Pure Deterministic Environmental Alert Engine
Evaluates verified environmental observations and forecasts against user notification preferences.
Strict scientific integrity:
- Zero LLM decision making for alert triggers.
- Never trigger CPCB AQI alerts on invalid or insufficient pollutant suites.
- Never send alerts from DEMO_FIXTURE observations to real users.
- Enforces duplicate prevention, cooldown periods, escalation, recovery, and quiet hours.
"""
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple, Any
import uuid

from app.core.config import settings
from app.services.quality import check_observation_staleness, PROVIDER_STALENESS_THRESHOLDS_MINUTES
from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult, AQICategory, CalculationStatus
from app.schemas.forecast import ForecastCurrentResponse, HorizonForecastStep
from app.schemas.alert import (
    AlertItem,
    AlertSeverity,
    AlertType,
    UserAlertPreferenceResponse,
)


class AlertCandidate:
    """Represents a potential alert evaluated deterministically before state checks."""
    def __init__(
        self,
        alert_type: AlertType,
        severity: AlertSeverity,
        station_code: str,
        station_name: str,
        pollutant: Optional[str],
        observed_value: Optional[float],
        threshold_value: Optional[float],
        unit: str,
        source_provenance: str,
        observation_timestamp: datetime,
        trigger_reason: str,
        recommended_precaution: str,
        is_forecast: bool = False,
        forecast_horizon_hours: Optional[int] = None,
        is_recovery: bool = False,
    ):
        self.alert_id = str(uuid.uuid4())
        self.alert_type = alert_type
        self.severity = severity
        self.station_code = station_code
        self.station_name = station_name
        self.pollutant = pollutant
        self.observed_value = observed_value
        self.threshold_value = threshold_value
        self.unit = unit
        self.source_provenance = source_provenance
        self.observation_timestamp = observation_timestamp
        self.trigger_reason = trigger_reason
        self.recommended_precaution = recommended_precaution
        self.is_forecast = is_forecast
        self.forecast_horizon_hours = forecast_horizon_hours
        self.is_recovery = is_recovery


def get_recommended_precaution(aqi: Optional[int], pollutant: str, category: Optional[AQICategory] = None) -> str:
    """Returns deterministic health guidance aligned strictly with CPCB advisories."""
    if aqi is None:
        return "Air quality readings require close monitoring. Minimize prolonged outdoor exertion if sensitive."

    if aqi <= 100:
        return "Air quality is within acceptable parameters. Safe for normal outdoor activity."
    elif aqi <= 200:
        return "Sensitive individuals (children, elderly, respiratory conditions) should limit prolonged outdoor exertion."
    elif aqi <= 300:
        return "People with respiratory or cardiac conditions should avoid outdoor exertion. General public should reduce heavy outdoor tasks."
    elif aqi <= 400:
        return "Avoid prolonged outdoor exertion. Wear certified particulate filtering respirators (N95/FFP2). Keep indoor air purifiers active."
    else:
        return "Critical health hazard. Avoid all outdoor activities. Remain indoors with sealed windows. Vulnerable groups must seek clinical advice if experiencing respiratory distress."


def is_in_quiet_hours(now_dt: datetime, start_hour: int, end_hour: int) -> bool:
    """Checks if current time falls within user-specified quiet hours (24-hr format)."""
    current_hour = now_dt.hour
    if start_hour == end_hour:
        return False
    if start_hour < end_hour:
        return start_hour <= current_hour < end_hour
    else:
        # Crosses midnight (e.g. 22:00 to 07:00)
        return current_hour >= start_hour or current_hour < end_hour


class EnvironmentalAlertEngine:
    """
    Deterministic rule engine evaluating environmental observations and forecasts.
    """

    @staticmethod
    def evaluate_observation(
        obs: EnvironmentalObservationInput,
        aqi_result: Optional[AQICalculationResult],
        pref: UserAlertPreferenceResponse,
        previous_obs: Optional[Dict[str, Any]] = None,
        active_tracker: Optional[Dict[str, Any]] = None,
    ) -> List[AlertCandidate]:
        """
        Evaluates a live/estimated observation against user preferences.
        Strictly suppresses alerts on DEMO_FIXTURE observations.
        """
        candidates: List[AlertCandidate] = []

        # STRICT INTEGRITY: Never send live alerts from DEMO_FIXTURE or HISTORICAL data to real users
        if obs.data_source_type in (DataSourceType.DEMO_FIXTURE, DataSourceType.HISTORICAL):
            return []

        station_code = obs.station_id or f"GRID-{obs.location.latitude:.2f}-{obs.location.longitude:.2f}"
        station_name = obs.station_name or f"Monitoring Station ({station_code})"
        provider_name = obs.provider or "Physical Station"
        provenance = f"{provider_name} ({obs.data_source_type.value})"
        obs_time = obs.timestamp if obs.timestamp.tzinfo else obs.timestamp.replace(tzinfo=timezone.utc)

        # 1. Provider-Aware Freshness and Timestamp Anomaly Validation
        is_stale, age_minutes = check_observation_staleness(
            timestamp=obs_time,
            provider_name=obs.provider,
            data_source_type=obs.data_source_type,
        )

        # Future-dated check (clock anomaly / uncalibrated timestamp)
        if age_minutes < -5.0 and obs.data_source_type != DataSourceType.FORECAST:
            candidates.append(
                AlertCandidate(
                    alert_type=AlertType.DATA_FRESHNESS,
                    severity=AlertSeverity.INFO,
                    station_code=station_code,
                    station_name=station_name,
                    pollutant=None,
                    observed_value=round(-age_minutes, 1),
                    threshold_value=0.0,
                    unit="minutes",
                    source_provenance=provenance,
                    observation_timestamp=obs_time,
                    trigger_reason=f"Station telemetry has a future timestamp (advanced by {-age_minutes:.1f} min). Live alerts are suppressed to prevent clock-anomaly false triggers.",
                    recommended_precaution="Data stream clock synchronization required. Live observation alerts are paused.",
                )
            )
            return candidates

        # Provider-specific staleness check
        if is_stale:
            # Determine applicable provider threshold in minutes
            provider_thresh_min = settings.DATA_STALE_THRESHOLD_MINUTES
            if obs.provider:
                clean_p = obs.provider.lower().replace("-", "_").replace(" ", "_")
                for p_key, p_thresh in PROVIDER_STALENESS_THRESHOLDS_MINUTES.items():
                    clean_k = p_key.lower().replace("-", "_").replace(" ", "_")
                    if clean_k in clean_p or clean_p in clean_k:
                        provider_thresh_min = p_thresh
                        break

            age_hours = round(max(0.0, age_minutes) / 60.0, 1)
            thresh_hours = round(provider_thresh_min / 60.0, 1)

            candidates.append(
                AlertCandidate(
                    alert_type=AlertType.DATA_FRESHNESS,
                    severity=AlertSeverity.INFO,
                    station_code=station_code,
                    station_name=station_name,
                    pollutant=None,
                    observed_value=age_hours,
                    threshold_value=thresh_hours,
                    unit="hours",
                    source_provenance=provenance,
                    observation_timestamp=obs_time,
                    trigger_reason=f"Station telemetry from {provider_name} is outdated by {age_hours:.1f} hours (provider threshold: {thresh_hours:.1f}h). Real-time alerts are paused until fresh data arrives.",
                    recommended_precaution="Rely on regional satellite or model-estimated values until physical station telemetry resumes.",
                )
            )
            return candidates

        # 2. Overall CPCB AQI Alert
        if aqi_result is not None:
            # STRICT REQUIREMENT: Never trigger an official CPCB AQI alert when AQI is INVALID
            if aqi_result.status == CalculationStatus.VALID and aqi_result.overall_aqi is not None:
                aqi_val = aqi_result.overall_aqi

                # Threshold check
                if aqi_val >= pref.aqi_threshold:
                    # Determine severity
                    if aqi_val <= 100:
                        sev = AlertSeverity.INFO
                    elif aqi_val <= 200:
                        sev = AlertSeverity.WARNING
                    elif aqi_val <= 300:
                        sev = AlertSeverity.WARNING
                    elif aqi_val <= 400:
                        sev = AlertSeverity.DANGER
                    else:
                        sev = AlertSeverity.CRITICAL

                    candidates.append(
                        AlertCandidate(
                            alert_type=AlertType.AQI_THRESHOLD,
                            severity=sev,
                            station_code=station_code,
                            station_name=station_name,
                            pollutant=aqi_result.prominent_pollutant,
                            observed_value=float(aqi_val),
                            threshold_value=float(pref.aqi_threshold),
                            unit="AQI",
                            source_provenance=provenance,
                            observation_timestamp=obs_time,
                            trigger_reason=f"CPCB AQI reached {aqi_val} ({aqi_result.category.value if aqi_result.category else 'Elevated'}), exceeding your threshold of {pref.aqi_threshold}.",
                            recommended_precaution=get_recommended_precaution(aqi_val, aqi_result.prominent_pollutant or "", aqi_result.category),
                        )
                    )

                # Recovery Check: If previously in alert and now below threshold - 15 hysteresis points
                if pref.recovery_alerts_enabled and active_tracker and active_tracker.get("is_in_alert"):
                    hysteresis_threshold = pref.aqi_threshold - 15
                    if aqi_val <= hysteresis_threshold:
                        candidates.append(
                            AlertCandidate(
                                alert_type=AlertType.RECOVERY,
                                severity=AlertSeverity.INFO,
                                station_code=station_code,
                                station_name=station_name,
                                pollutant=aqi_result.prominent_pollutant,
                                observed_value=float(aqi_val),
                                threshold_value=float(pref.aqi_threshold),
                                unit="AQI",
                                source_provenance=provenance,
                                observation_timestamp=obs_time,
                                trigger_reason=f"Conditions improved: CPCB AQI dropped to {aqi_val} ({aqi_result.category.value if aqi_result.category else 'Moderate'}), well below your threshold of {pref.aqi_threshold}.",
                                recommended_precaution="Air quality has normalized. Outdoor ventilation and activities may resume.",
                                is_recovery=True,
                            )
                        )

        # 3. PM2.5 Threshold Alert
        if obs.pm2_5 is not None and obs.pm2_5 >= pref.pm25_threshold:
            val = obs.pm2_5
            if val < 90.0:
                sev = AlertSeverity.WARNING
            elif val < 150.0:
                sev = AlertSeverity.DANGER
            else:
                sev = AlertSeverity.CRITICAL

            candidates.append(
                AlertCandidate(
                    alert_type=AlertType.PM25_THRESHOLD,
                    severity=sev,
                    station_code=station_code,
                    station_name=station_name,
                    pollutant="PM2.5",
                    observed_value=val,
                    threshold_value=float(pref.pm25_threshold),
                    unit="µg/m³",
                    source_provenance=provenance,
                    observation_timestamp=obs_time,
                    trigger_reason=f"Fine particulate matter (PM2.5) concentration of {val:.1f} µg/m³ exceeds your threshold of {pref.pm25_threshold:.1f} µg/m³.",
                    recommended_precaution=get_recommended_precaution(int(val * 2.5), "PM2.5"),
                )
            )

        # 4. PM10 Threshold Alert
        if obs.pm10 is not None and obs.pm10 >= pref.pm10_threshold:
            val = obs.pm10
            if val < 150.0:
                sev = AlertSeverity.WARNING
            elif val < 250.0:
                sev = AlertSeverity.DANGER
            else:
                sev = AlertSeverity.CRITICAL

            candidates.append(
                AlertCandidate(
                    alert_type=AlertType.PM10_THRESHOLD,
                    severity=sev,
                    station_code=station_code,
                    station_name=station_name,
                    pollutant="PM10",
                    observed_value=val,
                    threshold_value=float(pref.pm10_threshold),
                    unit="µg/m³",
                    source_provenance=provenance,
                    observation_timestamp=obs_time,
                    trigger_reason=f"Coarse particulate matter (PM10) concentration of {val:.1f} µg/m³ exceeds your threshold of {pref.pm10_threshold:.1f} µg/m³.",
                    recommended_precaution=get_recommended_precaution(int(val), "PM10"),
                )
            )

        # 5. Sudden Deterioration Alert
        if pref.sudden_deterioration_enabled and previous_obs and aqi_result and aqi_result.overall_aqi is not None:
            prev_aqi = previous_obs.get("calculated_aqi")
            prev_pm25 = previous_obs.get("pm2_5")
            curr_aqi = aqi_result.overall_aqi

            is_spike = False
            spike_reason = ""

            if prev_aqi is not None and (curr_aqi - prev_aqi) >= settings.ALERT_SPIKE_DELTA_AQI:
                is_spike = True
                spike_reason = f"CPCB AQI spiked by {curr_aqi - prev_aqi} points (from {prev_aqi} to {curr_aqi}) rapidly."
            elif prev_pm25 is not None and obs.pm2_5 is not None and prev_pm25 > 20.0:
                pm25_delta = obs.pm2_5 - prev_pm25
                if (pm25_delta / prev_pm25) >= settings.ALERT_SPIKE_RATIO_PM25:
                    is_spike = True
                    spike_reason = f"PM2.5 surged by {int(pm25_delta / prev_pm25 * 100)}% (from {prev_pm25:.1f} to {obs.pm2_5:.1f} µg/m³) in recent hours."

            if is_spike:
                candidates.append(
                    AlertCandidate(
                        alert_type=AlertType.SUDDEN_DETERIORATION,
                        severity=AlertSeverity.DANGER if curr_aqi < 350 else AlertSeverity.CRITICAL,
                        station_code=station_code,
                        station_name=station_name,
                        pollutant=aqi_result.prominent_pollutant or "AQI",
                        observed_value=float(curr_aqi),
                        threshold_value=float(settings.ALERT_SPIKE_DELTA_AQI),
                        unit="AQI points",
                        source_provenance=provenance,
                        observation_timestamp=obs_time,
                        trigger_reason=f"Rapid atmospheric deterioration detected at {station_name}: {spike_reason}",
                        recommended_precaution="Sudden localized pollution surge. Suspend strenuous outdoor activities immediately and close ventilation points.",
                    )
                )

        return candidates

    @staticmethod
    def evaluate_forecast(
        forecast: ForecastCurrentResponse,
        pref: UserAlertPreferenceResponse,
        active_tracker: Optional[Dict[str, Any]] = None,
    ) -> List[AlertCandidate]:
        """
        Evaluates future forecast steps against user preferences.
        Strict scientific limits:
        - Only evaluates operational horizons (+1h, +3h, +6h) that have validated evaluation data.
        - Suppresses unverified long horizons (+12h, +24h).
        - Clearly labels all warnings as predictive FORECAST.
        """
        if not pref.forecast_alerts_enabled:
            return []

        candidates: List[AlertCandidate] = []
        station_code = forecast.station_id
        station_name = forecast.station_name

        # Operational horizons with validated baseline benchmarks
        VALIDATED_HORIZONS = [1, 3, 6]

        for step in forecast.horizons:
            if step.horizon_hours not in VALIDATED_HORIZONS:
                continue

            target_ts = step.target_timestamp if step.target_timestamp.tzinfo else step.target_timestamp.replace(tzinfo=timezone.utc)

            # 1. Forecast AQI check
            if step.forecast_aqi is not None and step.cpcb_status == CalculationStatus.VALID:
                if step.forecast_aqi >= pref.aqi_threshold:
                    sev = AlertSeverity.WARNING if step.forecast_aqi < 301 else AlertSeverity.DANGER
                    candidates.append(
                        AlertCandidate(
                            alert_type=AlertType.FORECAST_WARNING,
                            severity=sev,
                            station_code=station_code,
                            station_name=station_name,
                            pollutant=step.prominent_pollutant or "PM2.5",
                            observed_value=float(step.forecast_aqi),
                            threshold_value=float(pref.aqi_threshold),
                            unit="AQI (Forecast)",
                            source_provenance="FORECAST",
                            observation_timestamp=target_ts,
                            trigger_reason=f"Predicted +{step.horizon_hours}h CPCB AQI ({step.forecast_aqi}) is forecast to exceed your threshold of {pref.aqi_threshold}.",
                            recommended_precaution=f"Plan outdoor schedules ahead. Atmospheric conditions indicate elevated {step.prominent_pollutant or 'pollution'} in {step.horizon_hours} hour(s).",
                            is_forecast=True,
                            forecast_horizon_hours=step.horizon_hours,
                        )
                    )

        return candidates

    @staticmethod
    def should_dispatch_alert(
        candidate: AlertCandidate,
        pref: UserAlertPreferenceResponse,
        active_tracker: Optional[Dict[str, Any]] = None,
        now_dt: Optional[datetime] = None,
    ) -> Tuple[bool, str]:
        """
        Determines whether an alert candidate passes cooldown, escalation, duplicate, and quiet-hours checks.
        Returns: (should_dispatch: bool, dispatch_status: str)
        """
        if not pref.notifications_enabled:
            return False, "DISABLED"

        if now_dt is None:
            now_dt = datetime.now(timezone.utc)

        # Recovery alerts always bypass cooldown to notify user of safe conditions
        if candidate.is_recovery:
            return True, "DELIVERED"

        # Check Quiet Hours
        if pref.quiet_hours_enabled and is_in_quiet_hours(now_dt, pref.quiet_hours_start, pref.quiet_hours_end):
            # Still record alert in database, but suppress active push notification
            return True, "QUIET_HOURS_SUPPRESSED"

        if not active_tracker:
            return True, "DELIVERED"

        last_time = active_tracker.get("last_triggered_at") or active_tracker.get("last_alert_time")
        last_val = active_tracker.get("last_observed_value")
        last_sev = active_tracker.get("last_severity")

        if last_time:
            if last_time.tzinfo is None:
                last_time = last_time.replace(tzinfo=timezone.utc)

            time_diff = (now_dt - last_time).total_seconds() / 60.0

            # Within Cooldown Period
            if time_diff < settings.ALERT_COOLDOWN_MINUTES:
                # Escalation check:
                is_escalation = False

                # 1. Value escalated significantly (e.g. +50 AQI)
                if candidate.observed_value is not None and last_val is not None:
                    if (candidate.observed_value - last_val) >= settings.ALERT_ESCALATION_DELTA_AQI:
                        is_escalation = True

                # 2. Severity jumped (e.g. WARNING -> DANGER / CRITICAL)
                sev_order = {AlertSeverity.INFO: 1, AlertSeverity.WARNING: 2, AlertSeverity.DANGER: 3, AlertSeverity.CRITICAL: 4}
                curr_sev_rank = sev_order.get(candidate.severity, 2)
                last_sev_rank = sev_order.get(AlertSeverity(last_sev), 2) if last_sev else 2
                if curr_sev_rank > last_sev_rank:
                    is_escalation = True

                if is_escalation:
                    return True, "ESCALATED_DELIVERED"
                else:
                    # Suppressed by cooldown
                    return False, "COOLDOWN_SUPPRESSED"

        return True, "DELIVERED"


alert_engine = EnvironmentalAlertEngine()
