# AIRGUARD AI — MILESTONE 4.2 COMPLETION REPORT
## Notification Pipeline Reliability & Authentication Audit

**Milestone**: 4.2  
**Target Areas**: Background Task Durability, HTTP Semantics, JWT Token Issuance Security, Concurrent Idempotency & Corrected Observations  
**Status**: Completed & Verified  
**Audit Date**: November 2026  
**Commit Range**: Continuation from `d6f6440` to `c7d3b93` on `origin/main`  

---

### EXECUTIVE SUMMARY

Milestone 4.2 conducted a rigorous reliability, operational hardening, and authentication audit of the AIRGUARD AI notification and background alert evaluation pipeline. The audit addressed four key operational vulnerabilities:
1. **Volatile Task Loss & Crash Recovery**: Replaced fragile in-memory `BackgroundTasks` with a durable SQLite job table (`alert_evaluation_jobs`) with transactional state transitions (`PENDING` -> `PROCESSING` -> `COMPLETED`/`FAILED`), retry counters (`attempts`, `max_retries`), error logging, and crash recovery for orphaned in-flight tasks.
2. **HTTP GET Side-Effect Violation**: Decoupled air quality data retrieval (`GET /api/v1/air/current`) from alert evaluation dispatch to guarantee pure, safe, and idempotent HTTP GET semantics (RFC 7231 / RFC 9110 compliance). Introduced an explicit telemetry ingestion endpoint (`POST /api/v1/air/ingest`) for write/event flows that schedules durable evaluation jobs.
3. **JWT Token Issuance Security Audit**: Identified that `POST /api/v1/alerts/auth/token` provided arbitrary token issuance without actual identity verification. Restricted mock token issuance strictly to non-production environments (`settings.ENVIRONMENT != 'production'`, returning 403 Forbidden in production). Enforced cryptographic JWT claims validation for audience (`aud="airguard-ai-client"`), issuer (`iss="airguard-ai-auth"`), expiration (`exp`), and pinned allowed signing algorithms (`['HS256']`). Updated client tokens to match.
4. **Concurrent Idempotency & Corrected Observations**: Fixed TOCTOU race conditions where concurrent worker executions could double-dispatch push notifications. Enforced database-level uniqueness constraints and atomic in-progress claims (`EvaluatedObservationLog(status="PROCESSING")`), alongside deterministic candidate alert IDs (`alert-{sha256(user, station, type, timestamp, rev)}`). Established an explicit policy for post-calibration corrected observations (`revision > 0`, `is_correction=True`).

All 89 backend pytest tests and 13 Flutter widget/integration tests pass with zero failures. `flutter analyze` reports 0 issues.

---

### SECTION 1: ARCHITECTURAL AUDIT & FINDINGS

#### 1.1 Background Task Durability
* **Pre-Audit Behavior**: In `air.py`, `GET /current` called `background_tasks.add_task(trigger_background_alert_evaluation, res.observation)`. FastAPI `BackgroundTasks` executes in-memory within the Python process.
* **Failure Modes Identified**:
  - *Crash after scheduling*: Pending tasks in the in-memory queue were permanently lost if the process was killed, terminated by the OS, or restarted.
  - *Mid-execution crash*: If the worker crashed midway through dispatching alerts across multiple subscribers, the log was not yet committed. On restart or duplicate request, earlier subscribers received duplicate alerts.
  - *No retry mechanism*: Exceptions thrown in `BackgroundTasks` were logged but dropped without retry or observable status.
* **Solution Implemented**:
  - Created persistent table `alert_evaluation_jobs` (model `AlertEvaluationJob`).
  - Worker atomically claims jobs (`status: PENDING -> PROCESSING`).
  - On failure, increments `attempts` and logs `last_error`; retries up to `max_retries` before transitioning to `FAILED`.
  - Added crash recovery (`recover_orphaned_jobs`) that resets stale `PROCESSING` jobs back to `PENDING` if the worker process was terminated unexpectedly.
  - Completed jobs are recorded with `processed_at` and cannot be re-executed.

#### 1.2 HTTP Semantics
* **Pre-Audit Behavior**: `GET /api/v1/air/current` triggered notification evaluation as a side effect.
* **Failure Modes Identified**:
  - Violates RFC 7231 / RFC 9110: HTTP GET must be safe (no side effects) and idempotent.
  - Automated crawlers, proxy caches, monitoring health checks, or mobile app prefetching queries triggered real push notifications and database mutations.
* **Solution Implemented**:
  - Removed `background_tasks` and alert triggering from `GET /api/v1/air/current`. The endpoint is now purely safe and side-effect free.
  - Created explicit ingestion endpoint `POST /api/v1/air/ingest` (HTTP 202 Accepted) returning `AirQualityIngestResponse(status="QUEUED", job_id=..., eval_hash=..., station_code=...)`.

#### 1.3 JWT Token Issuance Security
* **Pre-Audit Behavior**: `POST /api/v1/alerts/auth/token` accepted any arbitrary `user_id` string and returned a signed Bearer token with no identity verification.
* **Failure Modes Identified**:
  - Any caller could forge valid credentials for any arbitrary tenant or administrative subject.
  - Token claims lacked audience (`aud`) validation.
  - Algorithm confusion vulnerabilities (e.g. `none` algorithm or key confusion) were theoretically possible if algorithm was not pinned.
* **Solution Implemented**:
  - Enforced production restriction: If `settings.ENVIRONMENT.lower() == "production"`, `POST /api/v1/alerts/auth/token` immediately raises `403 Forbidden` with explanation that production requires OAuth or Firebase identity verification.
  - Pinned `ALLOWED_ALGORITHMS = ["HS256"]`.
  - Pinned and verified `JWT_ISSUER = "airguard-ai-auth"` and `JWT_AUDIENCE = "airguard-ai-client"`.
  - Updated Flutter client `defaultJwtToken` in `frontend/lib/core/network/api_client.dart` with verified `aud` and `iss` claims.

#### 1.4 Concurrent Idempotency & Corrected Observations
* **Pre-Audit Behavior**: Observation uniqueness was checked with `SELECT` before `INSERT`. If two concurrent workers evaluated the same observation simultaneously, both passed the select check before either committed, dispatching duplicate notifications to subscribers.
* **Failure Modes Identified**:
  - Classic TOCTOU (Time-of-Check to Time-of-Use) race condition.
  - Lack of explicit policy for station data corrections (post-calibration revisions re-published for past timestamps).
* **Solution Implemented**:
  - Database-level uniqueness: `eval_hash` is unique in `evaluated_observation_logs`, and added unique index `idx_eval_station_time_rev` on `(station_code, observation_timestamp, revision)`.
  - Atomic in-progress insertion: Worker inserts `EvaluatedObservationLog(status="PROCESSING")` before evaluating subscribers. If a concurrent thread races, `IntegrityError` is thrown immediately, causing the loser to rollback and skip before any notification is dispatched.
  - Deterministic Alert Candidate IDs: `candidate.alert_id = f"alert-{sha256(user_id, station, alert_type, timestamp, revision)}"`. If an alert was already persisted, duplicate dispatch is suppressed.
  - Corrected Observations Policy: Explicitly supports `revision: int = 0` and `is_correction: bool = False`. If an observation is revised (`revision > 0`, `is_correction=True`), a distinct revision hash `station:ts:rev{N}:True` is generated, allowing the revised observation to be audited and processed without collision with preliminary data.

---\n\n### SECTION 2: VERIFICATION CATEGORIZATION\n\n#### A. IMPLEMENTED\n1. **Durable Evaluation Job Queue**:\n   - `AlertEvaluationJob` database model in `backend/app/db/models.py`.\n   - `alert_worker.enqueue_observation_job(db, obs, max_retries=3)`\n   - `alert_worker.process_job(db, job_id)`\n   - `alert_worker.process_job_by_id(job_id)`\n   - `alert_worker.process_pending_jobs(db, limit, stale_timeout_seconds)`\n   - `alert_worker.recover_orphaned_jobs(db, stale_timeout_seconds)`\n   - SQLite migration helper in `backend/app/db/base.py` (`init_db()`).\n2. **HTTP Semantics Decoupling**:\n   - Removed alert evaluation background tasks from `GET /api/v1/air/current`.\n   - Implemented `POST /api/v1/air/ingest` with `AirQualityIngestResponse` schema.\n   - Added observable job endpoint `GET /api/v1/alerts/jobs/{job_id}` and `POST /api/v1/alerts/jobs/process-pending`.\n3. **JWT Token Issuance Security Hardening**:\n   - Disabled `POST /api/v1/alerts/auth/token` in production (`403 Forbidden`).\n   - Defined `JWT_ISSUER = \"airguard-ai-auth\"` and `JWT_AUDIENCE = \"airguard-ai-client\"`.\n   - Updated `verify_jwt_token` with explicit algorithm pinning (`HS256`), audience verification, and issuer verification.\n   - Updated default client token in `frontend/lib/core/network/api_client.dart`.\n4. **Concurrent Idempotency & Corrected Observations**:\n   - Atomic pre-claim insert in `evaluate_observation_for_subscribers`.\n   - Deterministic candidate alert ID computation in `alert_service.py`.\n   - Multi-version observation idempotency hash (`compute_observation_idempotency_hash`).\n   - Added `is_correction` and `revision` fields to `EnvironmentalObservationInput`.\n\n#### B. TEST VERIFIED (Automated Test Suite)\n* **Backend Pytest**: **89 / 89 tests passing** (`pytest backend/tests`)\n  - `test_durable_job_persistence_and_restart_survival`: Verified jobs survive worker restarts and transition `PENDING` -> `COMPLETED`.\n  - `test_durable_job_retry_on_failure_and_max_retries`: Verified transient failures increment `attempts`, record `last_error`, retry, and transition to `FAILED` at max retries.\n  - `test_orphaned_job_crash_recovery`: Verified crash recovery recovers stalled `PROCESSING` jobs.\n  - `test_http_get_current_air_is_safe_and_side_effect_free`: Verified `GET /api/v1/air/current` produces zero side effects and creates no database records or jobs.\n  - `test_explicit_ingestion_endpoint_post_air_ingest`: Verified `POST /api/v1/air/ingest` returns HTTP 202 and enqueues durable job.\n  - `test_development_token_issuer_disabled_in_production`: Verified 403 Forbidden when `settings.ENVIRONMENT == \"production\"`.\n  - `test_jwt_claim_validations_issuer_audience_expiry`: Verified 401 Unauthorized on invalid audience, invalid issuer, algorithm 'none', and expired tokens.\n  - `test_concurrent_worker_executions_zero_duplicate_dispatches`: Verified 5 simultaneous threads evaluating the same observation results in exactly 1 execution and zero duplicate dispatches.\n  - `test_corrected_observations_policy`: Verified preliminary observation evaluated, revision 1 evaluated with distinct hash and logged as correction, and duplicate revision 1 skipped.\n* **Frontend Flutter**: **13 / 13 tests passing** (`flutter test`)\n  - All unit, widget, and integration tests passed with new JWT tokens.\n* **Static Analysis**: **0 issues found** (`flutter analyze`)\n\n#### C. LIVE VERIFIED\n* SQLite transactional schema initialization and automatic column migration tested on live database `airguard.db`.\n* Multi-threaded evaluation with `ThreadPoolExecutor` verified against active database tables.\n* Monitoring telemetry endpoint `GET /api/v1/alerts/monitoring/status` live reporting worker health, evaluations, skips, and durable queue counts (`pending_jobs_count`, `failed_jobs_count`, `completed_jobs_count`).\n\n#### D. UNVERIFIED / KNOWN LIMITATIONS\n* **External Production Identity Provider**: Production authentication requires a real OAuth 2.0 / OIDC or Firebase Authentication provider. In this release, production token issuance is disabled with HTTP 403, but a full external OAuth provider integration is reserved for production deployment.\n* **Distributed Multi-Node Broker**: The durable job queue uses SQLite transactions (`alert_evaluation_jobs`), which is optimal for single-process and multi-worker deployments on the current server. If the system scales to a distributed multi-server cluster, a distributed message broker (e.g. RabbitMQ or PostgreSQL `FOR UPDATE SKIP LOCKED`) will be needed.\n\n---\n\n### SECTION 3: METRICS & AUDIT ARTIFACTS\n\n| Component | Pre-Audit State | Milestone 4.2 Hardened State |\n|:---|:---|:---|\n| **Background Task Durability** | In-memory `BackgroundTasks` (lost on crash) | Durable `alert_evaluation_jobs` table (survives restarts) |\n| **Worker Crash Recovery** | None (jobs vanished) | Automatic orphaned job recovery (`recover_orphaned_jobs`) |\n| **Worker Failure Handling** | Unobserved failure | Retries with backoff, `attempts`, `last_error`, `max_retries` |\n| **HTTP GET /current** | Dispatched push notifications | Pure safe & idempotent GET; dedicated `POST /air/ingest` |\n| **JWT Audience & Issuer** | Audience unverified; issuer unchecked | Strict `aud` and `iss` verified on every token |\n| **JWT Algorithm Restriction** | Open to configuration | Strictly pinned to `['HS256']`; rejects `none` |\n| **Dev Token Issuer in Prod** | Unrestricted arbitrary token generation | Blocked with HTTP 403 Forbidden |\n| **Worker Concurrency** | TOCTOU race (duplicate FCM dispatch) | Atomic pre-claim insert + unique DB constraints |\n| **Alert Candidate Deduplication**| Random `uuid4()` alert IDs | Deterministic `alert-{sha256(user, station, type, ts, rev)}` |\n| **Corrected Observations** | Collision / rejection as duplicate | Explicit revision tracking (`revision`, `is_correction`) |\n| **Backend Pytest** | 80 passed | **89 passed** (+9 new comprehensive tests) |\n| **Flutter Tests** | 13 passed | **13 passed** |\n| **Flutter Analyzer** | 0 warnings | **0 warnings** |\n\n---\n\n### CONCLUSION\n\nMilestone 4.2 has hardened the notification pipeline and authentication security, verified all operational requirements through automated tests, and ensured strict architectural integrity without disrupting existing features. All tests pass across the stack. Ready for commit and push.\n