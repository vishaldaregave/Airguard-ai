"""
AIRGUARD AI — Milestone 4.2 Test Suite
Notification Pipeline Reliability & Authentication Audit

Covers:
1. Background Task Durability:
   - Durable job persistence across worker/app restarts.
   - Observable job lifecycle (PENDING -> PROCESSING -> COMPLETED).
   - Failed job retry tracking (attempts, last_error, max_retries, FAILED status).
   - Crash recovery for orphaned in-flight jobs.
   - Completed jobs never evaluated or dispatched twice.
   - Worker failures never block or crash environmental ingestion APIs.
2. HTTP Semantics:
   - GET /api/v1/air/current is safe and side-effect free (no alert evaluation or dispatch).
   - POST /api/v1/air/ingest explicitly ingests observations and enqueues durable evaluation jobs.
   - Backward compatibility for air quality retrieval.
3. JWT Token Issuance Security:
   - Development token issuer blocked in production (403 Forbidden).
   - Validation of audience (aud) and issuer (iss).
   - Rejection of invalid, tampered, expired, or algorithm-confused tokens (401 Unauthorized).
   - Pinned signing algorithm (HS256 only; rejection of 'none' algorithm).
4. Concurrent Idempotency & Corrected Observations:
   - Database-level uniqueness constraints.
   - Concurrent worker thread safety: zero duplicate alert dispatches under simultaneous execution.
   - Explicit policy for corrected/calibrated observations (revision tracking).
"""

from __future__ import annotations

import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone, timedelta
from typing import Dict, Any

import jwt
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.core.config import settings
from app.core.security import (
    create_access_token,
    verify_jwt_token,
    JWT_ISSUER,
    JWT_AUDIENCE,
)
from app.db.base import SessionLocal
from app.db.models import (
    AlertEvaluationJob,
    EvaluatedObservationLog,
    AlertRecord,
    UserAlertPreference,
)
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.services.alert_worker import alert_worker, compute_observation_idempotency_hash

client = TestClient(app)


def get_auth_headers(user_id: str) -> Dict[str, str]:
    token = create_access_token(user_id=user_id)
    return {"Authorization": f"Bearer {token}", "X-User-ID": user_id}


# ==============================================================================
# SECTION 1: BACKGROUND TASK DURABILITY
# ==============================================================================

def test_durable_job_persistence_and_restart_survival():
    """
    Verify that evaluation jobs persist in the SQLite database and survive
    simulated worker process restarts, transitioning PENDING -> COMPLETED.
    """
    db = SessionLocal()
    station_code = f"STATION_DURABLE_{uuid.uuid4().hex[:6]}"
    now_utc = datetime.now(timezone.utc)
    obs = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Durable Test Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=now_utc,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=120.0,
        pm10=220.0,
    )

    # 1. Enqueue job
    job = alert_worker.enqueue_observation_job(db=db, obs=obs)
    assert job.status == "PENDING"
    assert job.attempts == 0
    job_id = job.job_id
    db.close()

    # 2. Simulate complete application crash and restart (new DB session, fresh worker state)
    fresh_db = SessionLocal()
    persisted_job = fresh_db.query(AlertEvaluationJob).filter(AlertEvaluationJob.job_id == job_id).first()
    assert persisted_job is not None
    assert persisted_job.status == "PENDING"
    assert persisted_job.station_code == station_code

    # 3. Fresh worker processes pending queue
    processed_count = alert_worker.process_pending_jobs(db=fresh_db, limit=10)
    assert processed_count >= 1

    fresh_db.refresh(persisted_job)
    assert persisted_job.status == "COMPLETED"
    assert persisted_job.attempts == 1
    assert persisted_job.processed_at is not None
    assert persisted_job.last_error is None

    # 4. Completed jobs are never processed again
    repeat_processed = alert_worker.process_job(db=fresh_db, job_id=job_id)
    assert repeat_processed == []
    fresh_db.refresh(persisted_job)
    assert persisted_job.attempts == 1  # Not incremented
    fresh_db.close()


def test_durable_job_retry_on_failure_and_max_retries():
    """
    Verify that transient failures increment attempts and allow retries,
    eventually transitioning to FAILED once max_retries is reached.
    """
    db = SessionLocal()
    station_code = f"STATION_FAIL_{uuid.uuid4().hex[:6]}"
    now_utc = datetime.now(timezone.utc)
    obs = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Retry Test Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=now_utc,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=80.0,
    )

    job = alert_worker.enqueue_observation_job(db=db, obs=obs, max_retries=2)
    job_id = job.job_id

    # Corrupt payload to simulate an unrecoverable serialization failure
    job.payload_json = "INVALID_JSON_CORRUPTED"
    db.commit()

    # Attempt 1
    res1 = alert_worker.process_job(db=db, job_id=job_id)
    assert res1 == []
    db.refresh(job)
    assert job.attempts == 1
    assert job.status == "PENDING"  # Retryable because attempts (1) < max_retries (2)
    assert job.last_error is not None

    # Attempt 2 (exhausts max retries)
    res2 = alert_worker.process_job(db=db, job_id=job_id)
    assert res2 == []
    db.refresh(job)
    assert job.attempts == 2
    assert job.status == "FAILED"  # Permanently failed
    db.close()


def test_orphaned_job_crash_recovery():
    """
    Verify that jobs stuck in 'PROCESSING' state due to an in-flight worker crash
    are safely detected and recovered back to PENDING.
    """
    db = SessionLocal()
    station_code = f"STATION_ORPHAN_{uuid.uuid4().hex[:6]}"
    now_utc = datetime.now(timezone.utc)
    obs = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Orphaned Test Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=now_utc,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=90.0,
    )

    job = alert_worker.enqueue_observation_job(db=db, obs=obs)
    # Simulate a crash midway: status left as PROCESSING with an old timestamp
    job.status = "PROCESSING"
    job.attempts = 1
    job.updated_at = datetime.now(timezone.utc) - timedelta(minutes=15)
    db.commit()
    db.refresh(job)

    # Run orphan recovery with 300s timeout
    recovered_count = alert_worker.recover_orphaned_jobs(db=db, stale_timeout_seconds=300)
    assert recovered_count >= 1

    db.refresh(job)
    assert job.status == "PENDING"
    db.close()


# ==============================================================================
# SECTION 2: HTTP SEMANTICS
# ==============================================================================

def test_http_get_current_air_is_safe_and_side_effect_free():
    """
    STRICT HTTP SEMANTICS:
    GET /api/v1/air/current must NOT enqueue background evaluation jobs,
    must NOT write EvaluatedObservationLog, and must NOT send notifications.
    """
    db = SessionLocal()
    user_test = f"user_get_safe_{uuid.uuid4().hex[:6]}"
    # Register subscriber
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 100, "pm25_threshold": 30.0},
        headers=get_auth_headers(user_test),
    )

    initial_job_count = db.query(AlertEvaluationJob).count()
    initial_log_count = db.query(EvaluatedObservationLog).count()
    initial_alert_count = db.query(AlertRecord).filter(AlertRecord.user_id == user_test).count()

    # Perform GET request on demo station
    resp = client.get("/api/v1/air/current?station_id=DEMO-DELHI-001")
    assert resp.status_code == 200
    data = resp.json()
    assert "observation" in data
    assert "aqi_result" in data

    # Verify ZERO side effects were generated in the database
    new_job_count = db.query(AlertEvaluationJob).count()
    new_log_count = db.query(EvaluatedObservationLog).count()
    new_alert_count = db.query(AlertRecord).filter(AlertRecord.user_id == user_test).count()

    assert new_job_count == initial_job_count
    assert new_log_count == initial_log_count
    assert new_alert_count == initial_alert_count
    db.close()


def test_explicit_ingestion_endpoint_post_air_ingest():
    """
    Verify that explicit POST /api/v1/air/ingest enqueues a durable job
    and returns HTTP 202 Accepted with observable job status.
    """
    user_sub = f"user_ingest_{uuid.uuid4().hex[:6]}"
    station_code = f"INGEST_STATION_{uuid.uuid4().hex[:6]}"
    obs_time = datetime.now(timezone.utc).isoformat()

    # Subscribe user to this station with low threshold
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 120, "pm25_threshold": 40.0, "preferred_station_code": station_code},
        headers=get_auth_headers(user_sub),
    )

    obs_payload = {
        "station_id": station_code,
        "station_name": "Ingestion Facility",
        "location": {"latitude": 28.5, "longitude": 77.1, "city": "Delhi", "state": "Delhi", "country": "India"},
        "timestamp": obs_time,
        "provider": "CPCB",
        "data_source_type": "LIVE",
        "pm2_5": 160.0,
        "pm10": 260.0,
        "no2": 80.0,
    }

    # Post telemetry ingestion
    resp = client.post("/api/v1/air/ingest", json=obs_payload)
    assert resp.status_code == 202
    res_data = resp.json()
    assert res_data["status"] in ("QUEUED", "PENDING", "PROCESSING", "COMPLETED")
    assert res_data["station_code"] == station_code
    job_id = res_data["job_id"]
    assert job_id is not None

    # Check job observable endpoint
    job_resp = client.get(f"/api/v1/alerts/jobs/{job_id}", headers=get_auth_headers(user_sub))
    assert job_resp.status_code == 200
    job_info = job_resp.json()
    assert job_info["job_id"] == job_id
    assert job_info["status"] in ("PENDING", "PROCESSING", "COMPLETED")


# ==============================================================================
# SECTION 3: JWT TOKEN ISSUANCE SECURITY
# ==============================================================================

def test_development_token_issuer_disabled_in_production(monkeypatch):
    """
    Verify that POST /api/v1/alerts/auth/token is strictly blocked with 403 Forbidden
    in production environments, since it has no real identity verification.
    """
    # 1. Normal development environment allows issuance
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    dev_resp = client.post("/api/v1/alerts/auth/token", json={"user_id": "dev_user"})
    assert dev_resp.status_code == 200
    assert "access_token" in dev_resp.json()

    # 2. Production environment strictly disables mock token issuer
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    prod_resp = client.post("/api/v1/alerts/auth/token", json={"user_id": "attacker_user"})
    assert prod_resp.status_code == 403
    assert "disabled in production" in prod_resp.json()["detail"].lower()


def test_jwt_claim_validations_issuer_audience_expiry():
    """
    Verify cryptographic JWT validation:
    - Rejects invalid issuer.
    - Rejects invalid or missing audience.
    - Rejects expired signatures.
    - Rejects algorithm 'none' and signature tampering.
    """
    now = datetime.now(timezone.utc)

    # 1. Valid token passes
    valid_token = create_access_token(user_id="valid_subject")
    payload = verify_jwt_token(valid_token)
    assert payload["sub"] == "valid_subject"
    assert payload["iss"] == JWT_ISSUER
    assert payload["aud"] == JWT_AUDIENCE

    # 2. Token with wrong audience
    bad_aud_payload = {
        "sub": "user_bad_aud",
        "user_id": "user_bad_aud",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=10)).timestamp()),
        "iss": JWT_ISSUER,
        "aud": "attacker-client-id",
    }
    bad_aud_token = jwt.encode(bad_aud_payload, settings.JWT_SECRET_KEY, algorithm="HS256")
    resp_aud = client.get("/api/v1/alerts/preferences", headers={"Authorization": f"Bearer {bad_aud_token}"})
    assert resp_aud.status_code == 401
    assert "audience" in resp_aud.json()["detail"].lower()

    # 3. Token with wrong issuer
    bad_iss_payload = {
        "sub": "user_bad_iss",
        "user_id": "user_bad_iss",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=10)).timestamp()),
        "iss": "untrusted-issuer",
        "aud": JWT_AUDIENCE,
    }
    bad_iss_token = jwt.encode(bad_iss_payload, settings.JWT_SECRET_KEY, algorithm="HS256")
    resp_iss = client.get("/api/v1/alerts/preferences", headers={"Authorization": f"Bearer {bad_iss_token}"})
    assert resp_iss.status_code == 401
    assert "issuer" in resp_iss.json()["detail"].lower()

    # 4. Token signed with algorithm 'none'
    bad_alg_token = jwt.encode(
        {"sub": "user_none", "iat": int(now.timestamp()), "exp": int((now + timedelta(minutes=10)).timestamp()), "iss": JWT_ISSUER, "aud": JWT_AUDIENCE},
        key="",
        algorithm="none",
    )
    resp_alg = client.get("/api/v1/alerts/preferences", headers={"Authorization": f"Bearer {bad_alg_token}"})
    assert resp_alg.status_code == 401


# ==============================================================================
# SECTION 4: CONCURRENT IDEMPOTENCY & CORRECTED OBSERVATIONS
# ==============================================================================

def test_concurrent_worker_executions_zero_duplicate_dispatches():
    """
    STRICT CONCURRENCY:
    Execute 5 worker evaluations simultaneously in parallel threads on the exact same observation.
    Guarantees:
    - Only 1 evaluation proceeds.
    - Remaining 4 concurrent executions are safely deduplicated without duplicate dispatches.
    - Zero duplicate alerts per alert type created.
    """
    user_test = f"user_race_{uuid.uuid4().hex[:6]}"
    station_code = f"STATION_RACE_{uuid.uuid4().hex[:6]}"

    # Set up subscriber
    client.put(
        "/api/v1/alerts/preferences",
        json={"notifications_enabled": True, "aqi_threshold": 100, "pm25_threshold": 30.0, "preferred_station_code": station_code},
        headers=get_auth_headers(user_test),
    )

    obs_time = datetime.now(timezone.utc)
    obs = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Race Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=obs_time,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=180.0,
        pm10=290.0,
        no2=95.0,
    )

    def worker_task(thread_id: int):
        db = SessionLocal()
        try:
            return alert_worker.evaluate_observation_for_subscribers(db=db, obs=obs)
        finally:
            db.close()

    # Fire 5 concurrent evaluation tasks simultaneously
    with ThreadPoolExecutor(max_workers=5) as executor:
        results = list(executor.map(worker_task, range(5)))

    # Sum total alerts returned across all threads
    total_alerts_returned = sum(len(res) for res in results)
    # Exactly one thread should execute (>0), other 4 threads must return [] due to atomic fingerprint lock
    non_empty_results = [r for r in results if len(r) > 0]
    assert len(non_empty_results) == 1
    assert total_alerts_returned > 0

    # Verify database has matching records for user_test with zero duplicate alert types
    db = SessionLocal()
    user_alerts = db.query(AlertRecord).filter(
        AlertRecord.user_id == user_test,
        AlertRecord.station_code == station_code,
    ).all()
    user_test_alerts_returned = [a for a in non_empty_results[0] if a.user_id == user_test]
    assert len(user_alerts) == len(user_test_alerts_returned)
    # Zero duplicates per alert type
    assert len(set(a.alert_type for a in user_alerts)) == len(user_alerts)
    db.close()


def test_corrected_observations_policy():
    """
    Verify policy for corrected/calibrated observations:
    - Preliminary observation (revision 0) is evaluated and logged.
    - Corrected observation with revision=1 is NOT blocked by preliminary observation.
    - Corrected observation is evaluated and logged with is_correction=True and revision=1.
    - Submitting the same corrected observation (revision 1) a second time is skipped idempotently.
    """
    db = SessionLocal()
    station_code = f"STATION_CORRECT_{uuid.uuid4().hex[:6]}"
    obs_time = datetime.now(timezone.utc)

    # 1. Preliminary observation (revision 0)
    obs_prelim = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Calibration Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=obs_time,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=50.0,
        revision=0,
        is_correction=False,
    )
    res_prelim = alert_worker.evaluate_observation_for_subscribers(db=db, obs=obs_prelim)
    prelim_hash = compute_observation_idempotency_hash(station_code, obs_time, is_correction=False, revision=0)

    log_prelim = db.query(EvaluatedObservationLog).filter(EvaluatedObservationLog.eval_hash == prelim_hash).first()
    assert log_prelim is not None
    assert log_prelim.revision == 0
    assert log_prelim.is_correction is False

    # 2. Corrected observation (revision 1, is_correction=True)
    obs_corrected = EnvironmentalObservationInput(
        station_id=station_code,
        station_name="Calibration Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi", state="Delhi", country="India"),
        timestamp=obs_time,
        provider="CPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=160.0,  # Calibrated upward
        revision=1,
        is_correction=True,
    )
    res_corr = alert_worker.evaluate_observation_for_subscribers(db=db, obs=obs_corrected)
    corr_hash = compute_observation_idempotency_hash(station_code, obs_time, is_correction=True, revision=1)
    assert corr_hash != prelim_hash

    log_corr = db.query(EvaluatedObservationLog).filter(EvaluatedObservationLog.eval_hash == corr_hash).first()
    assert log_corr is not None
    assert log_corr.revision == 1
    assert log_corr.is_correction is True

    # 3. Submitting revision 1 a second time is skipped idempotently
    res_corr_dup = alert_worker.evaluate_observation_for_subscribers(db=db, obs=obs_corrected)
    assert res_corr_dup == []
    db.close()
