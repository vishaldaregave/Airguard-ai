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
- **Explainable Environmental Exposure Risk Scorer**:
  - Quantified $0–100$ exposure risk score decomposed into explainable factor contributions (ambient AQI severity, multi-pollutant synergistic compounding, and meteorological atmospheric entrapment).
  - Grounded activity recommendations (outdoor cardio, transit, sensitive groups, home ventilation) with mandatory non-medical disclaimers.
- **Location Intelligence & Data Quality**:
  - GPS-based nearby station discovery with Haversine distance calculations.
  - Distinguishes monitoring station ambient readings from user's precise personal location.
  - Standard Temperature and Pressure (STP) gas conversions ($ppm$/$ppb$ to $\mu g/m^3$, $CO$ to $mg/m^3$).
  - Outlier rejection and staleness detection ($>120\text{ min}$).
  - In-memory async TTL caching (stations: 1 hr, observations: 15 min).
- **Premium Futuristic Mobile UI**:
  - Material 3 dark interface with custom circular arc gauge, dynamic category glow effects, distinct provenance badges, and telemetry inspection sheet.

---

## Architecture Overview

```
AirGuard-ai/
├── backend/
│   ├── app/
│   │   ├── api/v1/         # Endpoints: /locations, /stations, /air, /aqi, /health
│   │   ├── core/           # Configuration, settings, TTLs
│   │   ├── db/             # SQLAlchemy 2.0 models & connection
│   │   ├── engine/         # Deterministic CPCB AQI engine & Risk scorer
│   │   ├── providers/      # OpenAQ v3, Open-Meteo, CPCB data.gov.in, Demo fixtures
│   │   ├── schemas/        # Pydantic v2 data contracts
│   │   ├── services/       # Aggregator, geospatial (Haversine), Quality, TTL cache
│   │   └── main.py         # FastAPI application entrypoint
│   ├── tests/              # 41 Pytest tests covering math, providers, geo, quality, APIs
│   ├── requirements.txt
│   └── pytest.ini
├── frontend/
│   ├── lib/
│   │   ├── core/           # Constants, themes, network client, router, location service
│   │   ├── features/       # Models, repository, controller, dashboard, selector, widgets
│   │   └── main.dart       # Riverpod ProviderScope and Material 3 entrypoint
│   ├── test/               # Flutter widget and domain model unit tests
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
| `/api/v1/locations/nearby` | GET | Discover monitoring stations near GPS coordinates with Haversine distances. |
| `/api/v1/stations/nearby` | GET | List discovered stations sorted by distance from coordinates. |
| `/api/v1/stations/{station_id}` | GET | Get station metadata and monitored pollutant capabilities. |
| `/api/v1/air/current` | GET | Current normalized observation + CPCB AQI + explainable risk score. |
| `/api/v1/air/history` | GET | Historical time-series observations for a station. |
| `/api/v1/air/providers/status` | GET | Operational health, latency, authentication, and legal attribution for all providers. |
| `/api/v1/aqi/calculate` | POST | Pure deterministic CPCB AQI calculation from arbitrary input. |
| `/api/v1/aqi/demo-fixtures` | GET | Clearly labeled synthetic fixtures for development. |
| `/api/v1/health` | GET | Backend service status and standard verification. |

---

## Getting Started

### 1. Backend Setup (FastAPI)

```bash
cd backend
python -m venv venv
venv\Scripts\activate    # On Windows (or source venv/bin/activate on Linux/macOS)
pip install -r requirements.txt

# Run automated test suite (41 tests)
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

- **Backend**: **41/41 Pytest tests passing** covering Haversine distance, bounding box calculations, STP gas conversions ($ppb \to \mu g/m^3$, $CO \to mg/m^3$), negative and outlier rejection, staleness detection ($>120\text{ min}$), OpenAQ v3 mocked adapters (healthy, unauthenticated, rate-limited), Open-Meteo model adapter, CPCB data.gov.in adapter, demo fixture provider, and all REST API endpoints.
- **Frontend**: **5/5 Flutter tests passing** covering model serialization, station summaries, provider telemetry items, and widget tree rendering with mock repository. `flutter analyze` passing with **0 warnings / errors**.
