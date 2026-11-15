# AIRGUARD AI

**AIRGUARD AI** is an environmental intelligence platform for Android and cloud systems, built with Flutter, FastAPI, and deterministic environmental calculation engines.

---

## Key Features

- **Deterministic CPCB National AQI Engine**: Pure mathematical linear interpolation according to official Central Pollution Control Board (India) standards.
- **Strict Data Integrity**: Explicit attribution of data source types (`LIVE`, `HISTORICAL`, `ESTIMATED`, `DEMO_FIXTURE`). Stale observation detection and strict enforcement of the CPCB 3-pollutant criteria with mandatory particulate monitoring.
- **Explainable Environmental Exposure Risk**: Quantified 0–100 risk scoring with transparent factor contribution breakdowns (base AQI stress, multi-pollutant synergistic compounding, and atmospheric entrapment).
- **Grounded Activity Advisories**: Actionable recommendations for outdoor workouts, commuting, vulnerable demographics, and indoor filtration without medical claims.
- **Premium Futuristic UI**: Material 3 dark interface with custom sweeping circular AQI gauges, dynamic category glow effects, and responsive pollutant breakdowns.

---

## Architecture Overview

```
AirGuard-ai/
├── backend/
│   ├── app/
│   │   ├── api/v1/         # Endpoints: /aqi/calculate, /aqi/demo-fixtures, /health
│   │   ├── core/           # Configuration and settings
│   │   ├── db/             # SQLAlchemy 2.0 models & connection
│   │   ├── engine/         # Deterministic CPCB AQI engine & Risk scorer
│   │   ├── schemas/        # Pydantic v2 data contracts
│   │   └── main.py         # FastAPI application entrypoint
│   ├── tests/              # 14 Pytest test cases covering math & API contracts
│   ├── requirements.txt
│   └── pytest.ini
├── frontend/
│   ├── lib/
│   │   ├── core/           # Constants, themes, network client, router
│   │   ├── features/       # Environmental intelligence models, repo, screens, widgets
│   │   └── main.dart       # Riverpod ProviderScope and Material 3 entrypoint
│   ├── test/               # Flutter widget and domain model unit tests
│   └── pubspec.yaml
└── docs/
    ├── architecture.md
    └── cpcb_aqi_methodology.md
```

---

## Getting Started

### 1. Backend Setup (FastAPI)

```bash
cd backend
python -m venv venv
venv\Scripts\activate    # On Windows
pip install -r requirements.txt

# Run test suite
pytest -v

# Start FastAPI development server
uvicorn app.main:app --reload --port 8000
```
Interactive API docs are available at `http://127.0.0.1:8000/api/v1/docs`.

### 2. Mobile Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Run application on Android or desktop
flutter run
```

---

## Verification & Test Results

- **Backend**: 14/14 Pytest tests passing covering exact breakpoint math, 3-pollutant minimum validation, particulate requirement enforcement, staleness detection, and risk scoring.
- **Frontend**: Flutter static analysis (`flutter analyze`) passing with 0 warnings/errors. All unit and widget tests passing.
