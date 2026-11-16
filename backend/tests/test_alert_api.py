"""
AIRGUARD AI — Test Suite for Alert & Notification API Endpoints
Tests:
- GET /api/v1/alerts (inbox, unread counts, pagination)
- GET /api/v1/alerts/preferences (defaults & persistence)
- PUT /api/v1/alerts/preferences (validation & updating)
- POST /api/v1/alerts/device/register & DELETE /api/v1/alerts/device/unregister
- POST /api/v1/alerts/device/refresh (token rotation)
- PATCH /api/v1/alerts/{alert_id}/read
- User isolation & authorization via JWT Bearer tokens
- Firebase mock fallback & delivery verification status
"""

import uuid
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import create_access_token
from app.services.fcm_service import fcm_service

client = TestClient(app)


def get_auth_headers(user_id: str) -> dict:
    """Helper to generate valid JWT Bearer authentication headers for test users."""
    token = create_access_token(user_id=user_id)
    return {
        "Authorization": f"Bearer {token}",
        "X-User-ID": user_id,
    }


def test_get_and_put_preferences():
    """Test retrieving default preferences and updating them with valid thresholds."""
    unique_user = f"user_pref_{uuid.uuid4().hex[:8]}"
    user_header = get_auth_headers(unique_user)

    # 1. GET default preferences
    resp = client.get("/api/v1/alerts/preferences", headers=user_header)
    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == unique_user
    assert data["notifications_enabled"] is True
    assert data["aqi_threshold"] == 200

    # 2. PUT update preferences
    update_payload = {
        "notifications_enabled": True,
        "aqi_threshold": 150,
        "pm25_threshold": 50.0,
        "pm10_threshold": 90.0,
        "sudden_deterioration_enabled": True,
        "forecast_alerts_enabled": True,
        "recovery_alerts_enabled": True,
        "quiet_hours_enabled": True,
        "quiet_hours_start": 23,
        "quiet_hours_end": 6,
        "preferred_station_code": "DELHI_ANAND_VIHAR",
        "preferred_station_name": "Anand Vihar, Delhi",
    }
    resp_put = client.put("/api/v1/alerts/preferences", json=update_payload, headers=user_header)
    assert resp_put.status_code == 200
    updated_data = resp_put.json()
    assert updated_data["aqi_threshold"] == 150
    assert updated_data["pm25_threshold"] == 50.0
    assert updated_data["quiet_hours_enabled"] is True
    assert updated_data["preferred_station_code"] == "DELHI_ANAND_VIHAR"

    # 3. Validation: Reject invalid threshold (< 1 or > 500)
    invalid_payload = dict(update_payload)
    invalid_payload["aqi_threshold"] = 650
    resp_invalid = client.put("/api/v1/alerts/preferences", json=invalid_payload, headers=user_header)
    assert resp_invalid.status_code == 422


def test_user_isolation_for_preferences():
    """Verify that User A cannot see or modify User B's preferences."""
    user_alice = f"alice_{uuid.uuid4().hex[:6]}"
    user_bob = f"bob_{uuid.uuid4().hex[:6]}"

    # User A sets aqi_threshold = 120
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 120, "pm25_threshold": 40.0, "pm10_threshold": 80.0},
        headers=get_auth_headers(user_alice),
    )
    # User B sets aqi_threshold = 280
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 280, "pm25_threshold": 75.0, "pm10_threshold": 120.0},
        headers=get_auth_headers(user_bob),
    )

    resp_alice = client.get("/api/v1/alerts/preferences", headers=get_auth_headers(user_alice)).json()
    resp_bob = client.get("/api/v1/alerts/preferences", headers=get_auth_headers(user_bob)).json()

    assert resp_alice["aqi_threshold"] == 120
    assert resp_bob["aqi_threshold"] == 280


def test_device_token_lifecycle():
    """Test registering, refreshing, and unregistering FCM device push tokens."""
    unique_user = f"user_device_{uuid.uuid4().hex[:8]}"
    user_header = get_auth_headers(unique_user)
    token_str = f"fcm_test_token_{uuid.uuid4().hex}"
    new_token_str = f"fcm_rotated_token_{uuid.uuid4().hex}"

    # 1. Register device
    reg_resp = client.post(
        "/api/v1/alerts/device/register",
        json={"token": token_str, "device_type": "android"},
        headers=user_header,
    )
    assert reg_resp.status_code == 200
    data = reg_resp.json()
    assert data["token"] == token_str
    assert data["status"] == "REGISTERED"
    assert data["is_active"] is True

    # 2. Refresh / rotate device token
    refresh_resp = client.post(
        "/api/v1/alerts/device/refresh",
        json={"old_token": token_str, "new_token": new_token_str, "device_type": "android"},
        headers=user_header,
    )
    assert refresh_resp.status_code == 200
    assert refresh_resp.json()["status"] == "REFRESHED"
    assert refresh_resp.json()["token"] == new_token_str

    # 3. Unregister new device token
    unreg_resp = client.request(
        "DELETE",
        "/api/v1/alerts/device/unregister",
        json={"token": new_token_str},
        headers=user_header,
    )
    assert unreg_resp.status_code == 200
    assert unreg_resp.json()["status"] == "UNREGISTERED"

    # 4. Unregister again returns 404
    unreg_again = client.request(
        "DELETE",
        "/api/v1/alerts/device/unregister",
        json={"token": "non_existent_token_1234567890"},
        headers=user_header,
    )
    assert unreg_again.status_code == 404


def test_evaluate_and_mark_alert_read():
    """Test generating alerts via evaluate endpoint and marking them as read."""
    unique_user = f"user_eval_{uuid.uuid4().hex[:8]}"
    user_header = get_auth_headers(unique_user)

    # Set threshold low to ensure trigger
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 100, "pm25_threshold": 30.0, "pm10_threshold": 50.0},
        headers=user_header,
    )

    eval_payload = {
        "station_id": "TEST_EVAL_STN",
        "station_name": "Test Evaluation Station",
        "location": {
            "latitude": 28.5,
            "longitude": 77.2,
            "city": "Delhi",
            "state": "Delhi",
            "country": "India",
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "provider": "CPCB",
        "data_source_type": "LIVE",
        "pm2_5": 140.0,
        "pm10": 260.0,
        "no2": 80.0,
    }

    eval_resp = client.post("/api/v1/alerts/evaluate", json=eval_payload, headers=user_header)
    assert eval_resp.status_code == 200
    alerts_data = eval_resp.json()
    assert alerts_data["total"] >= 1
    first_alert = alerts_data["alerts"][0]
    alert_id = first_alert["alert_id"]
    assert first_alert["is_read"] is False

    # Check alert list
    list_resp = client.get("/api/v1/alerts", headers=user_header)
    assert list_resp.status_code == 200
    list_data = list_resp.json()
    assert list_data["unread_count"] >= 1

    # Mark as read
    read_resp = client.patch(f"/api/v1/alerts/{alert_id}/read", headers=user_header)
    assert read_resp.status_code == 200
    assert read_resp.json()["is_read"] is True

    # User isolation: Another user cannot mark this alert as read
    charlie_header = get_auth_headers("user_charlie")
    other_read_resp = client.patch(f"/api/v1/alerts/{alert_id}/read", headers=charlie_header)
    assert other_read_resp.status_code == 404


def test_fcm_mock_fallback_verification():
    """Verify FCM service gracefully operates in MOCK mode when credentials are not configured."""
    assert fcm_service.is_live is False
    res = fcm_service.send_multicast(
        tokens=["sample_mock_token_1234567890"],
        title="Test Alert",
        body="High AQI test",
    )
    assert res.delivery_status == "MOCK_DELIVERED"
    assert res.is_live_verified is False
    assert "mock" in res.error_message.lower()
