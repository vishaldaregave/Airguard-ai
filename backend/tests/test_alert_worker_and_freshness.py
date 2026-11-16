"""
AIRGUARD AI — Test Suite for Background Alert Worker, Provider-Aware Freshness & Monitoring
Tests:
- Automatic alert evaluation across multiple subscribers
- Per-location subscription filtering (preferred_station_code)
- Worker idempotency (no duplicate alerts for identical station + timestamp)
- Provider-specific freshness thresholds (OpenAQ 120m, Open-Meteo 90m, CPCB 180m)
- Future timestamp clock-anomaly rejection
- Operational monitoring telemetry & status endpoint
"""

import uuid
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import create_access_token
from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput, LocationCoordinate
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.alert_engine import alert_engine, AlertType
from app.services.alert_monitor import alert_monitor

client = TestClient(app)


def get_auth_headers(user_id: str) -> dict:
    token = create_access_token(user_id=user_id)
    return {"Authorization": f"Bearer {token}", "X-User-ID": user_id}


def test_provider_specific_freshness_thresholds():
    """Verify that the alert engine strictly applies provider-specific staleness rules."""
    loc = LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India")
    now_utc = datetime.now(timezone.utc)

    # 1. Open-Meteo model: threshold is 90 minutes. At 105 minutes, it is STALE.
    meteo_stale_time = now_utc - timedelta(minutes=105)
    obs_meteo = EnvironmentalObservationInput(
        station_id="METEO-GRID-01",
        station_name="Open-Meteo Regional Model",
        location=loc,
        timestamp=meteo_stale_time,
        provider="Open-Meteo",
        data_source_type=DataSourceType.ESTIMATED,
        pm2_5=95.0,
        pm10=160.0,
        no2=65.0,
    )
    pref = client.get("/api/v1/alerts/preferences", headers=get_auth_headers("test_user_fresh")).json()
    from app.schemas.alert import UserAlertPreferenceResponse
    pref_schema = UserAlertPreferenceResponse(**pref)

    candidates_meteo = alert_engine.evaluate_observation(
        obs=obs_meteo,
        aqi_result=calculate_cpcb_aqi(obs_meteo),
        pref=pref_schema,
    )
    types_meteo = [c.alert_type for c in candidates_meteo]
    assert AlertType.DATA_FRESHNESS in types_meteo
    assert AlertType.AQI_THRESHOLD not in types_meteo
    freshness_meteo = next(c for c in candidates_meteo if c.alert_type == AlertType.DATA_FRESHNESS)
    assert freshness_meteo.threshold_value == 1.5  # 90 minutes = 1.5 hours

    # 2. CPCB ground station: threshold is 180 minutes. At 150 minutes, it is STILL FRESH!
    cpcb_fresh_time = now_utc - timedelta(minutes=150)
    obs_cpcb = EnvironmentalObservationInput(
        station_id="CPCB-DELHI-01",
        station_name="CPCB Anand Vihar",
        location=loc,
        timestamp=cpcb_fresh_time,
        provider="cpcb_datagov",
        data_source_type=DataSourceType.LIVE,
        pm2_5=180.0,  # exceeds threshold
        pm10=280.0,
        no2=90.0,
    )
    candidates_cpcb = alert_engine.evaluate_observation(
        obs=obs_cpcb,
        aqi_result=calculate_cpcb_aqi(obs_cpcb),
        pref=pref_schema,
    )
    types_cpcb = [c.alert_type for c in candidates_cpcb]
    # At 150 minutes, CPCB is within 180 min threshold, so AQI threshold triggers
    assert AlertType.AQI_THRESHOLD in types_cpcb
    assert AlertType.DATA_FRESHNESS not in types_cpcb

    # 3. OpenAQ station: threshold is 120 minutes. At 135 minutes, it is STALE.
    openaq_stale_time = now_utc - timedelta(minutes=135)
    obs_openaq = EnvironmentalObservationInput(
        station_id="OPENAQ-DELHI-02",
        station_name="OpenAQ US Embassy",
        location=loc,
        timestamp=openaq_stale_time,
        provider="openaq",
        data_source_type=DataSourceType.LIVE,
        pm2_5=190.0,
        pm10=290.0,
        no2=95.0,
    )
    candidates_openaq = alert_engine.evaluate_observation(
        obs=obs_openaq,
        aqi_result=calculate_cpcb_aqi(obs_openaq),
        pref=pref_schema,
    )
    types_openaq = [c.alert_type for c in candidates_openaq]
    assert AlertType.DATA_FRESHNESS in types_openaq
    assert AlertType.AQI_THRESHOLD not in types_openaq


def test_future_timestamp_clock_anomaly_rejection():
    """Verify that observations with future timestamps (> 5m) are rejected to prevent false triggers."""
    loc = LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India")
    future_time = datetime.now(timezone.utc) + timedelta(minutes=45)

    obs = EnvironmentalObservationInput(
        station_id="DELHI_ANOMALY_01",
        station_name="Clock Anomaly Station",
        location=loc,
        timestamp=future_time,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=250.0,
        pm10=400.0,
        no2=100.0,
    )
    pref = client.get("/api/v1/alerts/preferences", headers=get_auth_headers("test_user_future")).json()
    from app.schemas.alert import UserAlertPreferenceResponse
    pref_schema = UserAlertPreferenceResponse(**pref)

    candidates = alert_engine.evaluate_observation(
        obs=obs,
        aqi_result=calculate_cpcb_aqi(obs),
        pref=pref_schema,
    )
    types = [c.alert_type for c in candidates]
    assert AlertType.AQI_THRESHOLD not in types
    assert AlertType.DATA_FRESHNESS in types
    anomaly_alert = next(c for c in candidates if c.alert_type == AlertType.DATA_FRESHNESS)
    assert "future timestamp" in anomaly_alert.trigger_reason.lower()


def test_worker_automatic_evaluation_and_idempotency():
    """Verify background worker evaluates subscribers and skips duplicates idempotently."""
    user_alpha = f"user_alpha_{uuid.uuid4().hex[:6]}"
    user_beta = f"user_beta_{uuid.uuid4().hex[:6]}"

    # Alpha monitors ALL stations with AQI threshold 120
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 120, "pm25_threshold": 40.0, "pm10_threshold": 80.0, "preferred_station_code": None},
        headers=get_auth_headers(user_alpha),
    )

    # Beta monitors ONLY station 'STATION_SPECIAL'
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 120, "pm25_threshold": 40.0, "pm10_threshold": 80.0, "preferred_station_code": "STATION_SPECIAL"},
        headers=get_auth_headers(user_beta),
    )

    fixed_timestamp = datetime.now(timezone.utc).isoformat()
    obs_payload = {
        "station_id": "STATION_OTHER",
        "station_name": "Other Station",
        "location": {"latitude": 28.5, "longitude": 77.1, "city": "Delhi", "state": "Delhi", "country": "India"},
        "timestamp": fixed_timestamp,
        "provider": "CPCB",
        "data_source_type": "LIVE",
        "pm2_5": 150.0,
        "pm10": 260.0,
        "no2": 85.0,
    }

    # 1. First evaluation: Alpha receives alert, Beta is filtered out (prefers 'STATION_SPECIAL')
    resp1 = client.post(
        "/api/v1/alerts/worker/evaluate-all",
        json=obs_payload,
        headers=get_auth_headers(user_alpha),
    )
    assert resp1.status_code == 200
    alerts1 = resp1.json()["alerts"]
    users_notified = {a["user_id"] for a in alerts1}
    assert user_alpha in users_notified
    assert user_beta not in users_notified

    # 2. Second evaluation with identical station + timestamp: Idempotency skip!
    resp2 = client.post(
        "/api/v1/alerts/worker/evaluate-all",
        json=obs_payload,
        headers=get_auth_headers(user_alpha),
    )
    assert resp2.status_code == 200
    # Must be 0 because duplicate hash is skipped
    assert resp2.json()["total"] == 0


def test_operational_monitoring_telemetry():
    """Verify that operational status endpoint reports evaluations, health, and masks secrets."""
    resp = client.get(
        "/api/v1/alerts/monitoring/status",
        headers=get_auth_headers("monitor_user"),
    )
    assert resp.status_code == 200
    data = resp.json()

    assert "worker_health" in data
    assert data["worker_health"] in ("HEALTHY", "DEGRADED", "ERROR")
    assert "evaluations_total_count" in data
    assert "idempotent_skips_count" in data
    assert "successful_deliveries_count" in data
    assert "failed_deliveries_count" in data
    assert "invalid_device_tokens_count" in data
    assert "fcm_mode" in data
    assert "token" not in data  # No tokens exposed
    assert "secret" not in data  # No secrets exposed
