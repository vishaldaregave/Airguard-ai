# AIRGUARD AI

**AIRGUARD AI** is an advanced, software-only environmental intelligence platform for Android and cloud backends. Built with Flutter, FastAPI, and deterministic environmental calculation engines, it transforms raw atmospheric sensor data and chemical transport models into actionable, location-specific environmental intelligence.

---

## Key Features

- **Multi-Provider Environmental Data Pipeline**:
  - **OpenAQ API v3**: Live physical ground-monitoring stations, sensor parameter discovery, and latest observations (`LIVE`).
  - **Open-Meteo Air Quality**: Regional chemical transport model grids providing current atmospheric estimates (`ESTIMATED`) and hourly forecasts (`FORECAST`).
  - **CPCB / data.gov.in**: National Ambient Air Quality Monitoring (CAAQMS/NAMP) official Open Government Data portal adapter.
  - **AirGuard Synthetic Demo Fixtures**: Isolated, clearly labeled fixtures for development and offline UI evaluation (`DEMO_FIXTURE`).
- **Deterministic CPCB National AQI Engine**:
  - Implements official Central Pollution Control Board (India) linear interpolation formulas across breakpoints for all 8 criteria pollutants ($\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{NO}_2$, $\text{SO}_2$, $\text{CO}$, $\text{O}_3$, $\text{NH}_3$, $\text{Pb}$).
  - Strictly enforces the CPCB mandate: at least 3 monitored pollutants required, with at least one particulate matter measurement ($\text{PM}_{2.5}$ or $\text{PM}_{10}$).
  - Incomplete suites return transparent individual sub-indices without fabricating a misleading overall AQI.
- **Scientific 24-Hour Forecasting Pipeline**:
  - Ridge Autoregressive ML models trained on strictly historical walk-forward splits.
  - Zero future data leakage: features at forecast time $t$ use only past observations ($t, t-1, t-2, t-3, t-6, t-12, t-24$), diurnal harmonic cycles, and weather features.
  - Persistent baseline benchmarks and empirical uncertainty intervals (10th to 90th percentiles).
- **Explainable Environmental Exposure Risk Scorer & AI Advisor**:
  - Quantified $0–100$ exposure risk score decomposed into explainable factor contributions (ambient AQI severity, multi-pollutant synergistic compounding, and meteorological atmospheric entrapment).
  - Grounded activity recommendations (outdoor cardio, transit, sensitive groups, home ventilation) with non-medical disclaimers.
  - High-performance local explainability engine with Gemini API adapter.
- **Deterministic Alert Engine & Durable Job Queue**:
  - Real-time rule-based alert triggering (Hazardous AQI, rapid degradation $\ge 50$ AQI/hr, sensitive group thresholds, persistent high exposure $\ge 3$ hrs).
  - Rejection of unsuitable observations: filters out synthetic demo fixtures, historical observations, stale data ($>120\text{ min}$), and uncalculable CPCB AQI.
  - Asynchronous background execution via durable SQLite job queue (`AlertEvaluationJob`) with atomic transitions (`PENDING` $\to$ `PROCESSING` $\to$ `COMPLETED`/`FAILED`), worker concurrency, lease timeouts, retry backoff, and crash recovery.
  - Strict HTTP GET semantics: `GET /api/v1/air/current` is guaranteed read-only with zero database write side effects. Ingestion is handled via `POST /api/v1/air/ingest`.
  - Production-hardened JWT authentication (audience, issuer, expiration, algorithm pinning; mock token generator blocked with 403 in production).
  - Multi-channel notification dispatch (FCM / Android system notifications) with transparent delivery tracking (`DELIVERED`, `MOCK_DELIVERED`, `FAILED`, `NO_TOKENS`).
- **Location Intelligence & Data Quality**:
  - GPS-based nearby station discovery with Haversine distance calculations.
  - Standard Temperature and Pressure (STP) gas conversions ($ppm$/$ppb$ to $\mu g/m^3$, $CO$ to $mg/m^3$).
  - Outlier rejection and staleness detection ($>120\text{ min}$).
  - In-memory async TTL caching (stations: 1 hr, observations: 15 min).
- **Premium Futuristic Mobile UI (Flutter)**:
  - Material 3 dark interface with custom circular arc gauge, dynamic category glow effects, distinct provenance badges, and telemetry inspection sheet.
  - 24-hour forecast timeline with confidence intervals and peak hazard warnings.
  - Real-time alert notifications banner, push token registration, and health guidance cards.

---

## Architecture Overview

```
AirGuard-ai/
├── backend/
│   ├── app/
│   │   ├── api/v1/         # Endpoints: /air, /aqi, /stations, /forecast, /alerts, /ai, /history
│   │   ├── core/           # Configuration, settings, TTLs, JWT auth
│   │   ├── db/             # SQLAlchemy 2.0 models & connection
│   │   ├── engine/         # Deterministic CPCB AQI, Risk scorer, Alert engine, Evaluator
│   │   ├── ml/             # Ridge AR forecasting, walk-forward validation, feature extraction
│   │   ├── notifications/  # FCM client, push dispatcher, delivery tracking
│   │   ├── providers/      # OpenAQ v3, Open-Meteo, CPCB data.gov.in, Demo fixtures
│   │   ├── schemas/        # Pydantic v2 data contracts
│   │   ├── services/       # Aggregator, geospatial, history, AI explain, alert jobs
│   │   └── main.py         # FastAPI application entrypoint
│   ├── tests/              # 89 Pytest tests covering math, ML, alerts, jobs, security, APIs
│   ├── requirements.txt
│   └── pytest.ini
├── frontend/
│   ├── lib/
│   │   ├── core/           # Constants, themes, network client, router, location service
│   │   ├── features/       # Models, repository, controller, dashboard, alerts, forecast
│   │   └── main.dart       # Riverpod ProviderScope and Material 3 entrypoint
│   ├── test/               # Flutter widget, domain model, and alert unit tests
│   └── pubspec.yaml
└── docs/
    ├── architecture.md
    ├── api-contract.md
    ├── data-sources.md
    ├── data-quality.md
    └── cpcb_aqi_methodology.md
```

---

## API Endpoints (v1)

| Endpoint | Method | Description |
|---|---|---|
| `/api/v1/health` | GET | Backend service status and standard verification. |
| `/api/v1/air/current` | GET | Safe read-only observation + CPCB AQI + risk score (zero side effects). |
| `/api/v1/air/ingest` | POST | Dedicated telemetry ingestion route recording observations to history. |
| `/api/v1/air/history` | GET | Historical time-series observations for a station. |
| `/api/v1/air/providers/status` | GET | Operational health, latency, auth, and attribution for all providers. |
| `/api/v1/aqi/calculate` | POST | Pure deterministic CPCB AQI calculation from arbitrary input. |
| `/api/v1/aqi/demo-fixtures` | GET | Clearly labeled synthetic fixtures for development. |
| `/api/v1/stations/nearby` | GET | List discovered stations sorted by distance from coordinates. |
| `/api/v1/stations/{station_id}` | GET | Get station metadata and monitored pollutant capabilities. |
| `/api/v1/locations/nearby` | GET | Discover monitoring stations near GPS coordinates with Haversine distance. |
| `/api/v1/forecast/predict` | POST | 24-hour Ridge ML pollutant and AQI forecast with uncertainty bounds. |
| `/api/v1/forecast/evaluate` | GET | Walk-forward validation metrics vs persistent baselines. |
| `/api/v1/ai/explain` | POST | Grounded environmental health reasoning and activity guidance. |
| `/api/v1/history/record` | POST | Explicitly ingest air quality observation into historical store. |
| `/api/v1/history/query` | GET | Query historical observations with filtering by time range and station. |
| `/api/v1/history/stats` | GET | Historical record coverage and pollutant availability statistics. |
| `/api/v1/alerts/evaluate` | POST | Trigger synchronous alert evaluation on current station telemetry. |
| `/api/v1/alerts/active` | GET | List currently active triggered alerts for a station or user. |
| `/api/v1/alerts/history` | GET | List historical alert events and resolution audit records. |
| `/api/v1/alerts/resolve` | POST | Resolve active alerts with timestamp and explanation. |
| `/api/v1/alerts/fcm-token` | POST | Register or update client device FCM push notification token. |
| `/api/v1/alerts/test-push` | POST | Dispatch test notification to verify delivery pipeline. |
| `/api/v1/alerts/dev/token` | POST | Generate mock development token (disabled with 403 in production). |
| `/api/v1/alerts/jobs/submit` | POST | Submit asynchronous alert evaluation job to durable queue. |
| `/api/v1/alerts/jobs/{job_id}` | GET | Check status and results of background alert evaluation job. |

---

## Getting Started

### 1. Backend Setup (FastAPI)

```bash
cd backend
python -m venv venv
venv\Scripts\activate    # On Windows (or source venv/bin/activate on Linux/macOS)
pip install -r requirements.txt

# Run automated test suite (89 tests)
pytest -v

# Start FastAPI development server
uvicorn app.main:app --reload --port 8000
```
Interactive OpenAPI documentation is available at `http://127.0.0.1:8000/api/v1/docs`.

### 2. Mobile Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget tests (13 tests)
flutter test

# Run application on Android or desktop
flutter run
```

---

## Verification & Test Results

- **Backend**: **89/89 Pytest tests passing** covering:
  - Haversine distance, STP conversions, outlier rejection, staleness detection ($>120\text{ min}$).
  - CPCB 8-pollutant breakpoint interpolation and 3-pollutant mandate enforcement.
  - Multi-provider adapters (OpenAQ v3, Open-Meteo, CPCB data.gov.in, demo fixtures).
  - Walk-forward Ridge ML forecasting and zero future-leakage verification.
  - Deterministic alert rule engine (Hazardous AQI, rapid spike, sensitive group, persistence).
  - Rejection of demo fixtures, historical observations, and invalid AQI from alerts.
  - Durable job queue state machine, concurrency, lease expiration, and crash recovery.
  - Safe GET semantics (zero side effects on query endpoints).
  - Production JWT security (audience, issuer, expiration, algorithm pinning, dev token blocking).
  - Multi-channel notification delivery tracking and state honesty.
- **Frontend**: **13/13 Flutter tests passing** covering:
  - Model serialization, station summaries, provider telemetry items.
  - Widget tree rendering with mock repository.
  - Loading indicators, empty states, error retry, null AQI indicators (`"--"`), and data integrity badges.
  - Real-time alert notifications banner and forecast timeline widgets.
  - `flutter analyze` passing with **0 issues found**.
