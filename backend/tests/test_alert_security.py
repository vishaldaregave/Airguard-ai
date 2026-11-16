"""
AIRGUARD AI — Test Suite for Alert Security, Authentication & User Isolation
Tests:
- Token-based authentication enforcement (401 Unauthorized on missing token)
- Invalid and expired token rejection (401 Unauthorized)
- Impersonation detection and prevention (403 Forbidden when X-User-ID != token subject)
- Cross-user device registration & unregistration prevention
- Cross-user alert history and read state isolation
"""

import time
import uuid
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient

from app.main import app
from app.core.security import create_access_token

client = TestClient(app)


def test_missing_authentication_token_rejected():
    """Verify that requests without Authorization Bearer token are rejected with 401."""
    # 1. No headers
    resp = client.get("/api/v1/alerts/preferences")
    assert resp.status_code == 401
    assert "Bearer" in resp.headers.get("WWW-Authenticate", "")

    # 2. Providing X-User-ID alone without Bearer token is strictly rejected
    resp_x_user = client.get("/api/v1/alerts/preferences", headers={"X-User-ID": "victim_user"})
    assert resp_x_user.status_code == 401
    assert "Authorization header" in resp_x_user.json()["detail"]


def test_invalid_and_expired_tokens_rejected():
    """Verify that tampered, malformed, or expired tokens are rejected with 401."""
    # 1. Malformed token
    resp_malformed = client.get(
        "/api/v1/alerts/preferences",
        headers={"Authorization": "Bearer invalid.token.payload"},
    )
    assert resp_malformed.status_code == 401

    # 2. Expired token
    expired_token = create_access_token(
        user_id="expired_user",
        expires_delta=timedelta(seconds=-10),  # expired 10 seconds ago
    )
    resp_expired = client.get(
        "/api/v1/alerts/preferences",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    assert resp_expired.status_code == 401
    assert "expired" in resp_expired.json()["detail"].lower()


def test_user_impersonation_strictly_forbidden():
    """STRICT INTEGRITY: A user cannot impersonate another user via X-User-ID."""
    user_attacker = f"attacker_{uuid.uuid4().hex[:6]}"
    user_victim = f"victim_{uuid.uuid4().hex[:6]}"

    attacker_token = create_access_token(user_id=user_attacker)

    # Attacker attempts to access victim's preferences by forging X-User-ID header
    resp = client.get(
        "/api/v1/alerts/preferences",
        headers={
            "Authorization": f"Bearer {attacker_token}",
            "X-User-ID": user_victim,
        },
    )
    assert resp.status_code == 403
    assert "Identity mismatch" in resp.json()["detail"]
    assert "Impersonation is prohibited" in resp.json()["detail"]


def test_cross_user_device_token_isolation():
    """Verify User B cannot unregister or refresh User A's device token."""
    user_alice = f"alice_dev_{uuid.uuid4().hex[:6]}"
    user_bob = f"bob_dev_{uuid.uuid4().hex[:6]}"

    alice_token = create_access_token(user_id=user_alice)
    bob_token = create_access_token(user_id=user_bob)

    alice_fcm = f"alice_fcm_token_{uuid.uuid4().hex}"
    bob_fcm = f"bob_fcm_token_{uuid.uuid4().hex}"

    # 1. Alice registers her device token
    resp_reg = client.post(
        "/api/v1/alerts/device/register",
        json={"token": alice_fcm, "device_type": "android"},
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert resp_reg.status_code == 200

    # 2. Bob attempts to unregister Alice's device token
    resp_unreg = client.request(
        "DELETE",
        "/api/v1/alerts/device/unregister",
        json={"token": alice_fcm},
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert resp_unreg.status_code == 404
    assert "Device token not found for this user" in resp_unreg.json()["detail"]

    # 3. Bob attempts to refresh Alice's device token
    resp_refresh = client.post(
        "/api/v1/alerts/device/refresh",
        json={"old_token": alice_fcm, "new_token": bob_fcm, "device_type": "android"},
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert resp_refresh.status_code == 404
    assert "Original device token not found for this user" in resp_refresh.json()["detail"]


def test_cross_user_alert_read_isolation():
    """Verify that User B cannot mark User A's alerts as read."""
    user_alice = f"alice_alert_{uuid.uuid4().hex[:6]}"
    user_bob = f"bob_alert_{uuid.uuid4().hex[:6]}"

    alice_token = create_access_token(user_id=user_alice)
    bob_token = create_access_token(user_id=user_bob)

    # Configure threshold for Alice
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 100, "pm25_threshold": 30.0, "pm10_threshold": 50.0},
        headers={"Authorization": f"Bearer {alice_token}"},
    )

    # Trigger alert for Alice
    obs_payload = {
        "station_id": "DELHI_STN_SEC",
        "station_name": "Delhi Security Station",
        "location": {"latitude": 28.6, "longitude": 77.2, "city": "Delhi", "state": "Delhi", "country": "India"},
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "provider": "CPCB",
        "data_source_type": "LIVE",
        "pm2_5": 160.0,
        "pm10": 280.0,
        "no2": 90.0,
    }
    eval_resp = client.post(
        "/api/v1/alerts/evaluate",
        json=obs_payload,
        headers={"Authorization": f"Bearer {alice_token}"},
    )
    assert eval_resp.status_code == 200
    alert_id = eval_resp.json()["alerts"][0]["alert_id"]

    # Bob attempts to mark Alice's alert as read
    patch_resp = client.patch(
        f"/api/v1/alerts/{alert_id}/read",
        headers={"Authorization": f"Bearer {bob_token}"},
    )
    assert patch_resp.status_code == 404
    assert "not found for this user" in patch_resp.json()["detail"]
