"""
AIRGUARD AI — Test Suite for Environmental Alert Engine
Tests:
- AQI threshold triggers
- PM2.5 and PM10 triggers
- Invalid CPCB AQI suppression
- Stale-data suppression
- Duplicate prevention & cooldown logic
- Recovery notifications
- Escalation logic
- Forecast provenance & horizon restrictions
- DEMO_FIXTURE alert suppression
"""

from datetime import datetime, timezone, timedelta
import pytest

from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput, LocationCoordinate
from app.schemas.aqi import AQICalculationResult, AQICategory, CalculationStatus
from app.schemas.alert import (
    AlertSeverity,
    AlertType,
    UserAlertPreferenceResponse,
)
from app.schemas.forecast import (
    ForecastCurrentResponse,
    ForecastModelMetadata,
    HorizonForecastStep,
    ModelType,
)
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.alert_engine import alert_engine, AlertCandidate, is_in_quiet_hours


@pytest.fixture
def base_preferences() -> UserAlertPreferenceResponse:
    return UserAlertPreferenceResponse(
        user_id="test_user_01",
        notifications_enabled=True,
        aqi_threshold=200,
        pm25_threshold=60.0,
        pm10_threshold=100.0,
        sudden_deterioration_enabled=True,
        forecast_alerts_enabled=True,
        recovery_alerts_enabled=True,
        quiet_hours_enabled=False,
        quiet_hours_start=22,
        quiet_hours_end=7,
        preferred_station_code=None,
        preferred_station_name=None,
        updated_at=datetime.now(timezone.utc),
    )


@pytest.fixture
def sample_location() -> LocationCoordinate:
    return LocationCoordinate(
        latitude=28.6139,
        longitude=77.2090,
        city="New Delhi",
        state="Delhi",
        country="India",
    )


def test_aqi_threshold_trigger(base_preferences, sample_location):
    """Test that valid CPCB AQI exceeding user threshold triggers an AQI_THRESHOLD alert."""
    obs = EnvironmentalObservationInput(
        station_id="DELHI_ANAND_VIHAR",
        station_name="Anand Vihar, Delhi",
        location=sample_location,
        timestamp=datetime.now(timezone.utc),
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=120.0,
        pm10=220.0,
        no2=85.0,  # 3 pollutants satisfy CPCB criteria
    )
    aqi_result = calculate_cpcb_aqi(obs)
    assert aqi_result.status == CalculationStatus.VALID
    assert aqi_result.overall_aqi is not None and aqi_result.overall_aqi >= 200

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=aqi_result,
        pref=base_preferences,
    )

    types = [c.alert_type for c in candidates]
    assert AlertType.AQI_THRESHOLD in types
    aqi_alert = next(c for c in candidates if c.alert_type == AlertType.AQI_THRESHOLD)
    assert aqi_alert.threshold_value == 200.0
    assert aqi_alert.is_forecast is False


def test_pm25_and_pm10_triggers(base_preferences, sample_location):
    """Test individual pollutant threshold triggers for PM2.5 and PM10."""
    obs = EnvironmentalObservationInput(
        station_id="DELHI_PUNJABI_BAGH",
        station_name="Punjabi Bagh, Delhi",
        location=sample_location,
        timestamp=datetime.now(timezone.utc),
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=85.0,   # exceeds 60.0 threshold
        pm10=140.0,   # exceeds 100.0 threshold
    )

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=None,
        pref=base_preferences,
    )

    types = [c.alert_type for c in candidates]
    assert AlertType.PM25_THRESHOLD in types
    assert AlertType.PM10_THRESHOLD in types


def test_invalid_cpcb_aqi_suppression(base_preferences, sample_location):
    """STRICT REQUIREMENT: Never trigger an official CPCB AQI alert when AQI calculation is INVALID."""
    obs = EnvironmentalObservationInput(
        station_id="DELHI_ITHO",
        station_name="ITO, Delhi",
        location=sample_location,
        timestamp=datetime.now(timezone.utc),
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=None,  # Insufficient pollutants -> Invalid calculation
        pm10=None,
        co=0.8,
    )
    aqi_result = calculate_cpcb_aqi(obs)
    assert aqi_result.status != CalculationStatus.VALID

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=aqi_result,
        pref=base_preferences,
    )

    types = [c.alert_type for c in candidates]
    assert AlertType.AQI_THRESHOLD not in types


def test_demo_fixture_suppression(base_preferences, sample_location):
    """STRICT REQUIREMENT: Never send alerts from DEMO_FIXTURE data to real users."""
    obs = EnvironmentalObservationInput(
        station_id="DEMO_STN_001",
        station_name="Simulated Station",
        location=sample_location,
        timestamp=datetime.now(timezone.utc),
        provider="AirGuard Demo Fixtures",
        data_source_type=DataSourceType.DEMO_FIXTURE,
        pm2_5=350.0,
        pm10=500.0,
        no2=150.0,
    )
    aqi_result = calculate_cpcb_aqi(obs)

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=aqi_result,
        pref=base_preferences,
    )
    assert len(candidates) == 0, "DEMO_FIXTURE observations must never generate user alerts"


def test_stale_data_suppression(base_preferences, sample_location):
    """Test that data older than ALERT_STALE_DATA_HOURS suppresses threshold alerts and triggers DATA_FRESHNESS alert."""
    stale_time = datetime.now(timezone.utc) - timedelta(hours=8)
    obs = EnvironmentalObservationInput(
        station_id="DELHI_STALE_01",
        station_name="Stale Station",
        location=sample_location,
        timestamp=stale_time,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=180.0,
        pm10=300.0,
        no2=95.0,
    )
    aqi_result = calculate_cpcb_aqi(obs)

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=aqi_result,
        pref=base_preferences,
    )

    types = [c.alert_type for c in candidates]
    assert AlertType.AQI_THRESHOLD not in types
    assert AlertType.PM25_THRESHOLD not in types
    assert AlertType.DATA_FRESHNESS in types
    freshness = next(c for c in candidates if c.alert_type == AlertType.DATA_FRESHNESS)
    assert freshness.observed_value >= 8.0


def test_cooldown_and_escalation_logic(base_preferences):
    """Test that alerts within cooldown period are suppressed unless condition escalates significantly."""
    now = datetime.now(timezone.utc)
    candidate = AlertCandidate(
        alert_type=AlertType.AQI_THRESHOLD,
        severity=AlertSeverity.WARNING,
        station_code="DELHI_ANAND_VIHAR",
        station_name="Anand Vihar",
        pollutant="PM2.5",
        observed_value=230.0,
        threshold_value=200.0,
        unit="AQI",
        source_provenance="LIVE",
        observation_timestamp=now,
        trigger_reason="AQI reached 230",
        recommended_precaution="Wear mask",
    )

    # 1. First alert without tracker: DELIVERED
    dispatch, status = alert_engine.should_dispatch_alert(candidate, base_preferences, None, now)
    assert dispatch is True
    assert status == "DELIVERED"

    # 2. Duplicate/unchanged condition within cooldown (e.g. 30 min later): COOLDOWN_SUPPRESSED
    tracker = {
        "last_alert_time": now - timedelta(minutes=30),
        "last_observed_value": 225.0,
        "last_severity": "WARNING",
        "is_in_alert": True,
    }
    dispatch, status = alert_engine.should_dispatch_alert(candidate, base_preferences, tracker, now)
    assert dispatch is False
    assert status == "COOLDOWN_SUPPRESSED"

    # 3. Escalation (+65 points jump, exceeds 50 delta): ESCALATED_DELIVERED
    severe_candidate = AlertCandidate(
        alert_type=AlertType.AQI_THRESHOLD,
        severity=AlertSeverity.DANGER,
        station_code="DELHI_ANAND_VIHAR",
        station_name="Anand Vihar",
        pollutant="PM2.5",
        observed_value=290.0,  # 290 - 225 = +65 jump
        threshold_value=200.0,
        unit="AQI",
        source_provenance="LIVE",
        observation_timestamp=now,
        trigger_reason="AQI escalated to 290",
        recommended_precaution="Stay indoors",
    )
    dispatch, status = alert_engine.should_dispatch_alert(severe_candidate, base_preferences, tracker, now)
    assert dispatch is True
    assert status == "ESCALATED_DELIVERED"


def test_recovery_alert_bypass_cooldown(base_preferences, sample_location):
    """Test that recovery alerts fire when conditions normalize below hysteresis threshold."""
    now = datetime.now(timezone.utc)
    obs = EnvironmentalObservationInput(
        station_id="DELHI_ANAND_VIHAR",
        station_name="Anand Vihar",
        location=sample_location,
        timestamp=now,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=35.0,
        pm10=70.0,
        no2=25.0,
    )
    aqi_result = calculate_cpcb_aqi(obs)
    assert aqi_result.overall_aqi is not None and aqi_result.overall_aqi <= 150

    tracker = {
        "is_in_alert": True,
        "last_observed_value": 240.0,
        "last_severity": "WARNING",
        "last_alert_time": now - timedelta(minutes=45),
    }

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=aqi_result,
        pref=base_preferences,
        active_tracker=tracker,
    )

    types = [c.alert_type for c in candidates]
    assert AlertType.RECOVERY in types
    rec_candidate = next(c for c in candidates if c.alert_type == AlertType.RECOVERY)
    assert rec_candidate.is_recovery is True

    # Recovery must bypass cooldown
    dispatch, status = alert_engine.should_dispatch_alert(rec_candidate, base_preferences, tracker, now)
    assert dispatch is True
    assert status == "DELIVERED"


def test_forecast_provenance_and_horizons(base_preferences, sample_location):
    """Test that forecast warnings are explicitly labeled and restricted to validated horizons."""
    now = datetime.now(timezone.utc)
    forecast = ForecastCurrentResponse(
        station_id="DELHI_LODHI_ROAD",
        station_name="Lodhi Road, Delhi",
        location=sample_location,
        forecast_generated_at=now,
        model_metadata=ForecastModelMetadata(
            model_id="ridge_v1",
            model_type=ModelType.AUTOREGRESSIVE_RIDGE,
            training_sample_count=2000,
            features_used=["lag_1", "lag_24"],
            last_trained_timestamp=now,
            status="OPERATIONAL",
        ),
        horizons=[
            # Validated +1h: AQI 240 exceeds threshold 200
            HorizonForecastStep(
                horizon_hours=1,
                target_timestamp=now + timedelta(hours=1),
                data_source_type=DataSourceType.FORECAST,
                forecast_aqi=240,
                forecast_category=AQICategory.POOR,
                forecast_color_code="#FF7E00",
                prominent_pollutant="PM2.5",
                cpcb_status=CalculationStatus.VALID,
                cpcb_status_message="Valid forecast AQI.",
            ),
            # Validated +3h: AQI 160 (below threshold)
            HorizonForecastStep(
                horizon_hours=3,
                target_timestamp=now + timedelta(hours=3),
                data_source_type=DataSourceType.FORECAST,
                forecast_aqi=160,
                forecast_category=AQICategory.MODERATE,
                forecast_color_code="#FFFF00",
                prominent_pollutant="PM2.5",
                cpcb_status=CalculationStatus.VALID,
                cpcb_status_message="Valid forecast AQI.",
            ),
            # Unvalidated +24h: AQI 350 (must be suppressed by operational horizon whitelist)
            HorizonForecastStep(
                horizon_hours=24,
                target_timestamp=now + timedelta(hours=24),
                data_source_type=DataSourceType.FORECAST,
                forecast_aqi=350,
                forecast_category=AQICategory.VERY_POOR,
                forecast_color_code="#99004C",
                prominent_pollutant="PM2.5",
                cpcb_status=CalculationStatus.VALID,
                cpcb_status_message="Valid forecast AQI.",
            ),
        ],
    )

    candidates = alert_engine.evaluate_forecast(forecast=forecast, pref=base_preferences)
    assert len(candidates) == 1
    fc_alert = candidates[0]
    assert fc_alert.alert_type == AlertType.FORECAST_WARNING
    assert fc_alert.is_forecast is True
    assert fc_alert.forecast_horizon_hours == 1
    assert fc_alert.source_provenance == "FORECAST"
    assert "Predicted +1h CPCB AQI" in fc_alert.trigger_reason


def test_quiet_hours_check():
    """Test 24-hr quiet hours detection across midnight boundary."""
    dt_night = datetime(2026, 11, 16, 23, 15, tzinfo=timezone.utc)
    dt_morning = datetime(2026, 11, 16, 6, 45, tzinfo=timezone.utc)
    dt_day = datetime(2026, 11, 16, 14, 0, tzinfo=timezone.utc)

    # 22:00 to 07:00
    assert is_in_quiet_hours(dt_night, 22, 7) is True
    assert is_in_quiet_hours(dt_morning, 22, 7) is True
    assert is_in_quiet_hours(dt_day, 22, 7) is False
