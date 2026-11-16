"""
AIRGUARD AI — Automatic Background Alert Evaluation Worker
Evaluates new environmental observations against all active user subscriptions.
Ensures:
- Strictly deterministic evaluation (no LLMs in decision path).
- Idempotent processing with database-level uniqueness constraints.
- Durable background job execution with restart survival and retry capability.
- Crash recovery for orphaned in-flight jobs.
- Safe concurrency preventing duplicate notification dispatch.
- Non-blocking execution so environmental ingestion APIs remain responsive.
- Real-time operational telemetry and health tracking.
"""

from __future__ import annotations

import hashlib
import json
import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.db.base import SessionLocal
from app.db.models import (
    EvaluatedObservationLog,
    UserAlertPreference,
    AlertEvaluationJob,
)
from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult
from app.schemas.alert import AlertItem
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.services.alert_service import alert_service
from app.services.alert_monitor import alert_monitor

logger = logging.getLogger(__name__)


def compute_observation_idempotency_hash(
    station_code: str,
    timestamp: datetime,
    is_correction: bool = False,
    revision: int = 0,
) -> str:
    """
    Computes a deterministic hash for station observation to enforce idempotency.
    Preserves backward compatibility for unrevised observations while allowing
    explicit revisions and corrections to be audited and processed safely.
    """
    ts_str = timestamp.isoformat() if timestamp.tzinfo else timestamp.replace(tzinfo=timezone.utc).isoformat()
    if revision > 0 or is_correction:
        raw = f"{station_code}:{ts_str}:rev{revision}:{is_correction}".encode("utf-8")
    else:
        raw = f"{station_code}:{ts_str}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


class AlertWorker:
    """
    Background evaluation engine coordinating durable, idempotent multi-subscriber environmental alerts.
    """

    def enqueue_observation_job(
        self,
        db: Session,
        obs: EnvironmentalObservationInput,
        max_retries: int = 3,
    ) -> AlertEvaluationJob:
        """
        Persists a durable evaluation job in the database.
        Survives server restarts and allows controlled retries.
        """
        station_code = obs.station_id or f"GRID-{obs.location.latitude:.2f}-{obs.location.longitude:.2f}"
        obs_time = obs.timestamp if obs.timestamp.tzinfo else obs.timestamp.replace(tzinfo=timezone.utc)
        is_corr = getattr(obs, "is_correction", False)
        rev = getattr(obs, "revision", 0)

        eval_hash = compute_observation_idempotency_hash(
            station_code=station_code,
            timestamp=obs_time,
            is_correction=is_corr,
            revision=rev,
        )

        # Check if job already exists for this fingerprint
        existing_job = db.query(AlertEvaluationJob).filter(
            AlertEvaluationJob.eval_hash == eval_hash
        ).first()

        if existing_job:
            # If already completed or in-progress, return existing job safely
            if existing_job.status in ("COMPLETED", "PROCESSING", "PENDING"):
                return existing_job
            # If failed but retries remain, re-queue
            if existing_job.status == "FAILED" and existing_job.attempts < existing_job.max_retries:
                existing_job.status = "PENDING"
                existing_job.updated_at = datetime.now(timezone.utc)
                db.commit()
                db.refresh(existing_job)
                return existing_job
            return existing_job

        # Create new durable job record
        job_id = f"job-{uuid.uuid4().hex[:16]}"
        job = AlertEvaluationJob(
            job_id=job_id,
            eval_hash=eval_hash,
            station_code=station_code,
            observation_timestamp=obs_time,
            payload_json=obs.model_dump_json(),
            status="PENDING",
            attempts=0,
            max_retries=max_retries,
            scheduled_at=datetime.now(timezone.utc),
        )
        db.add(job)
        db.commit()
        db.refresh(job)
        return job

    def process_job(self, db: Session, job_id: str) -> List[AlertItem]:
        """
        Atomically claims and processes a specific durable evaluation job.
        Transitions: PENDING -> PROCESSING -> COMPLETED (or FAILED with retry).
        """
        now = datetime.now(timezone.utc)
        # 1. Atomic claim to prevent concurrent worker execution
        claimed_rows = db.query(AlertEvaluationJob).filter(
            AlertEvaluationJob.job_id == job_id,
            AlertEvaluationJob.status.in_(["PENDING", "FAILED"]),
        ).update(
            {
                AlertEvaluationJob.status: "PROCESSING",
                AlertEvaluationJob.attempts: AlertEvaluationJob.attempts + 1,
                AlertEvaluationJob.updated_at: now,
            },
            synchronize_session="fetch",
        )
        db.commit()

        if claimed_rows == 0:
            logger.debug("Job %s could not be claimed (already processing or completed)", job_id)
            return []

        job = db.query(AlertEvaluationJob).filter(AlertEvaluationJob.job_id == job_id).first()
        if not job:
            return []

        try:
            obs = EnvironmentalObservationInput.model_validate_json(job.payload_json)
            dispatched = self.evaluate_observation_for_subscribers(db=db, obs=obs)

            # 2. Mark job as COMPLETED
            job.status = "COMPLETED"
            job.processed_at = datetime.now(timezone.utc)
            job.last_error = None
            job.updated_at = datetime.now(timezone.utc)
            db.commit()
            return dispatched
        except Exception as e:
            logger.error("AlertWorker: Error processing job %s: %s", job_id, str(e), exc_info=True)
            alert_monitor.record_error(f"Job {job_id} failed: {str(e)}")
            job.last_error = str(e)
            job.updated_at = datetime.now(timezone.utc)
            if job.attempts < job.max_retries:
                job.status = "PENDING"  # Eligible for retry
            else:
                job.status = "FAILED"
            db.commit()
            return []

    def process_job_by_id(self, job_id: str) -> None:
        """Helper for background tasks using an isolated database session."""
        db = SessionLocal()
        try:
            self.process_job(db=db, job_id=job_id)
        except Exception as e:
            logger.error("Background execution of job %s failed: %s", job_id, str(e), exc_info=True)
        finally:
            db.close()

    def recover_orphaned_jobs(self, db: Session, stale_timeout_seconds: int = 300) -> int:
        """
        Recovers jobs stuck in 'PROCESSING' state if the worker process crashed midway.
        """
        stale_threshold = datetime.now(timezone.utc) - timedelta(seconds=stale_timeout_seconds)
        orphaned = db.query(AlertEvaluationJob).filter(
            AlertEvaluationJob.status == "PROCESSING",
            AlertEvaluationJob.updated_at < stale_threshold,
        ).all()

        recovered_count = 0
        for job in orphaned:
            if job.attempts < job.max_retries:
                job.status = "PENDING"
                logger.warning("Recovered orphaned job %s back to PENDING (attempts: %d)", job.job_id, job.attempts)
            else:
                job.status = "FAILED"
                job.last_error = "Job timed out in PROCESSING state after crash"
                logger.warning("Marked orphaned job %s as FAILED (exceeded max retries)", job.job_id)
            job.updated_at = datetime.now(timezone.utc)
            recovered_count += 1

        if recovered_count > 0:
            db.commit()
        return recovered_count

    def process_pending_jobs(self, db: Session, limit: int = 10, stale_timeout_seconds: int = 300) -> int:
        """
        Recovers orphaned jobs and evaluates up to `limit` pending jobs from the queue.
        """
        self.recover_orphaned_jobs(db, stale_timeout_seconds=stale_timeout_seconds)

        pending_jobs = db.query(AlertEvaluationJob).filter(
            AlertEvaluationJob.status == "PENDING"
        ).order_by(AlertEvaluationJob.scheduled_at.asc()).limit(limit).all()

        processed_count = 0
        for job in pending_jobs:
            self.process_job(db=db, job_id=job.job_id)
            processed_count += 1

        return processed_count

    def evaluate_observation_for_subscribers(
        self,
        db: Session,
        obs: EnvironmentalObservationInput,
        aqi_result: Optional[AQICalculationResult] = None,
    ) -> List[AlertItem]:
        """
        Idempotently and atomically evaluates an observation across all subscribed users.
        Enforces database-level uniqueness to prevent concurrent double dispatch.
        """
        station_code = obs.station_id or f"GRID-{obs.location.latitude:.2f}-{obs.location.longitude:.2f}"
        obs_time = obs.timestamp if obs.timestamp.tzinfo else obs.timestamp.replace(tzinfo=timezone.utc)
        is_corr = getattr(obs, "is_correction", False)
        rev = getattr(obs, "revision", 0)

        eval_hash = compute_observation_idempotency_hash(
            station_code=station_code,
            timestamp=obs_time,
            is_correction=is_corr,
            revision=rev,
        )

        # 1. Reject synthetic DEMO_FIXTURE or HISTORICAL data from live alert pipeline
        if obs.data_source_type in (DataSourceType.DEMO_FIXTURE, DataSourceType.HISTORICAL):
            logger.debug(
                "AlertWorker: Skipping non-live data source (%s) for station %s",
                obs.data_source_type.value,
                station_code,
            )
            return []

        # 2. Check existing evaluation log (whether in-progress or completed)
        existing_eval = db.query(EvaluatedObservationLog).filter(
            EvaluatedObservationLog.eval_hash == eval_hash
        ).first()

        if existing_eval:
            logger.debug(
                "AlertWorker: Skipping in-progress or already-evaluated observation for station %s at %s (Hash: %s, Status: %s)",
                station_code,
                obs_time,
                eval_hash[:8],
                existing_eval.status,
            )
            alert_monitor.record_idempotent_skip(station_code)
            return []

        # 3. Concurrency Protection & Atomic Pre-Claim:
        # Attempt to insert an in-progress marker.
        # If a concurrent thread races to evaluate the same observation,
        # the database unique constraint on eval_hash will immediately fail for the loser.
        eval_log = EvaluatedObservationLog(
            eval_hash=eval_hash,
            station_code=station_code,
            observation_timestamp=obs_time,
            evaluated_at=datetime.now(timezone.utc),
            revision=rev,
            is_correction=is_corr,
            matched_subscriptions_count=0,
            dispatched_alerts_count=0,
            data_source_type=obs.data_source_type.value,
            status="PROCESSING",
        )
        db.add(eval_log)
        try:
            db.commit()
            db.refresh(eval_log)
        except IntegrityError:
            db.rollback()
            logger.debug(
                "AlertWorker: Concurrent execution detected for station %s at %s. Skipping duplicate dispatch.",
                station_code,
                obs_time,
            )
            alert_monitor.record_idempotent_skip(station_code)
            return []

        # Record ingestion event
        alert_monitor.record_ingestion(station_code, obs_time)

        # 4. Calculate CPCB AQI if not provided
        if aqi_result is None:
            aqi_result = calculate_cpcb_aqi(obs)

        # 5. Find all active user subscriptions eligible for this station
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
            "AlertWorker: Evaluating observation for %s (rev: %d, corr: %s) against %d active subscriber(s)",
            station_code,
            rev,
            is_corr,
            len(matching_subscribers),
        )

        all_dispatched: List[AlertItem] = []

        # 6. Evaluate for each subscriber
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

        # 7. Finalize idempotent evaluation log state
        eval_log.matched_subscriptions_count = len(matching_subscribers)
        eval_log.dispatched_alerts_count = len(all_dispatched)
        eval_log.status = "COMPLETED"
        eval_log.evaluated_at = datetime.now(timezone.utc)
        db.commit()

        # 8. Update operational monitoring
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
    Enqueues a durable job in the database and processes it safely without blocking APIs.
    """
    db = SessionLocal()
    try:
        job = alert_worker.enqueue_observation_job(db=db, obs=obs)
        alert_worker.process_job(db=db, job_id=job.job_id)
    except Exception as e:
        logger.error("Background alert evaluation failed: %s", str(e), exc_info=True)
        alert_monitor.record_error(f"Background task exception: {str(e)}")
    finally:
        db.close()
