# AIRGUARD AI — SYSTEM ARCHITECTURE

## 1. Architectural Philosophy
AirGuard AI is engineered as a software-only, production-grade environmental intelligence platform for Android and cloud backends. It strictly adheres to:
- **Clean Architecture & Separation of Concerns**: Clear boundary between presentation, domain, data access, deterministic environmental calculation engines, and machine learning analytics.
- **Uncompromised Data Integrity**: Real readings are distinguished from estimates, forecasts, or demo fixtures. Missing measurements are never treated as zero.
- **Deterministic AI & Explainable Analytics**: AQI calculations rely strictly on verified formulas. AI risk scoring provides quantified, explainable contribution breakdowns with non-medical disclaimers.

```
┌────────────────────────────────────────────────────────┐
│               AirGuard AI Flutter App                  │
│  (Material 3 Dark Futuristic • Riverpod • GoRouter)   │
└───────────────────────────┬────────────────────────────┘
                            │ Typed REST JSON Contracts
                            ▼
┌────────────────────────────────────────────────────────┐
│               FastAPI Backend Service                  │
│  (Pydantic v2 • SQLAlchemy 2.0 • OpenAPI Specification)│
├───────────────────────────┬────────────────────────────┤
│ Deterministic CPCB Engine │ Explainable Risk Engine    │
│ • Linear Interpolation    │ • Synergistic Compounding  │
│ • Minimum 3-Pollutant Rule│ • Atmospheric Stagnation   │
│ • Prominent Driver Logic  │ • Grounded Activity Recs   │
└───────────────────────────┴────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│              PostgreSQL / PostGIS Storage              │
│       (Monitoring Stations & Observation History)      │
└────────────────────────────────────────────────────────┘
```

## 2. Frontend Layer (Flutter / Dart)
- **State Management**: Flutter Riverpod (`StateNotifierProvider`, immutable states).
- **Navigation**: `GoRouter` declarative routing.
- **Network Client**: `Dio` with interceptors, timeouts, and fallback resilience.
- **Design System**: Material 3 dark futuristic aesthetic featuring deep charcoal surfaces (`#090D16`, `#111827`), emerald (`#00E5A3`) and cyan (`#00D2FF`) glow accents, and custom circular sweeps.

## 3. Backend Layer (Python / FastAPI)
- **Framework**: FastAPI (async ASGI) with Pydantic v2 validation.
- **Data Access**: SQLAlchemy 2.0 ORM with geospatial-ready indexing.
- **Engines**:
  - `cpcb_aqi.py`: Pure deterministic CPCB IND-AQI calculator implementing official 2014 Central Pollution Control Board equations.
  - `risk_scoring.py`: Multi-factor explainable exposure risk engine modeling chemical compounding and atmospheric stagnation without hallucinated medical claims.
