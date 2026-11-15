# AIRGUARD AI — SYSTEM ARCHITECTURE

## 1. Architectural Philosophy
AirGuard AI is engineered as a software-only, production-grade environmental intelligence platform for Android and cloud backends. It strictly adheres to:
- **Clean Architecture & Separation of Concerns**: Clear boundary between presentation, domain, data access, deterministic environmental calculation engines, multi-provider pipelines, and machine learning analytics.
- **Uncompromised Data Integrity**: Real readings are distinguished from estimates, forecasts, or demo fixtures. Missing measurements are never treated as zero.
- **Deterministic AI & Explainable Analytics**: AQI calculations rely strictly on verified formulas. AI risk scoring provides quantified, explainable contribution breakdowns with non-medical disclaimers.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AirGuard AI Flutter App                         │
│   (Material 3 Dark Futuristic • Riverpod • GoRouter • Geolocator)     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Typed REST JSON Contracts
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        FastAPI Backend Service                         │
│  (Pydantic v2 • SQLAlchemy 2.0 • OpenAPI Specification • In-Memory TTL)│
├───────────────────────────────────┬────────────────────────────────────┤
│ Deterministic CPCB Engine         │ Explainable Risk Engine            │
│ • Linear Interpolation            │ • Synergistic Compounding          │
│ • Minimum 3-Pollutant Rule        │ • Atmospheric Stagnation           │
│ • Prominent Driver Logic          │ • Grounded Activity Recs           │
├───────────────────────────────────┴────────────────────────────────────┤
│               Multi-Provider Environmental Pipeline                    │
│ • Geospatial Intelligence (Haversine & Radius Discovery)               │
│ • Data Quality Engine (25°C Ref Unit Normalization, Outlier Rejection) │
│ • Provider-Calibrated Freshness & Deduplication                        │
│ • TTL In-Memory Caching (Stations: 1hr, Observations: 15m)            │
└──────┬──────────────────────┬───────────────────────┬──────────────────┘
       │                      │                       │
       ▼                      ▼                       ▼
┌───────────────┐     ┌────────────────┐     ┌──────────────────┐
│  OpenAQ v3    │     │   Open-Meteo   │     │ CPCB data.gov.in │
│ (Ground LIVE) │     │ (Model ESTIM.) │     │  (National NAMP) │
└───────────────┘     └────────────────┘     └──────────────────┘
```

## 2. Frontend Layer (Flutter / Dart)
- **State Management**: Flutter Riverpod (`StateNotifierProvider`, immutable states).
- **Navigation**: `GoRouter` declarative routing.
- **Location Intelligence**: `LocationService` via `geolocator` plugin with fallback to regional centers when GPS is unavailable.
- **Network Client**: `Dio` with interceptors, timeouts, and fallback resilience.
- **Design System**: Material 3 dark futuristic aesthetic featuring deep charcoal surfaces (`#090D16`, `#111827`), emerald (`#00E5A3`) and cyan (`#00D2FF`) glow accents, circular canvas gauge, and distinct provenance badges (`LIVE`, `ESTIMATED`, `FORECAST`, `HISTORICAL`, `DEMO_FIXTURE`).

## 3. Backend Layer (Python / FastAPI)
- **Framework**: FastAPI (async ASGI) with Pydantic v2 validation.
- **Provider Pipeline Architecture**:
  - `BaseAirQualityProvider`: Standardized abstraction contract.
  - `OpenAQProvider`: Ground-station discovery and observation integration.
  - `OpenMeteoProvider`: Atmospheric chemical transport model integration (`ESTIMATED` / `FORECAST`).
  - `CPCBDataGovProvider`: Official National Data Sharing and Accessibility Policy (NDSAP) CAAQMS portal adapter.
  - `DemoFixtureProvider`: Clearly isolated synthetic fixtures for offline testing.
- **Engines & Services**:
  - `environmental_service.py`: Aggregator routing station requests, executing Haversine distance calculations, enforcing caching TTLs, deduplicating records, and feeding measurements into calculation engines.
  - `cpcb_aqi.py`: Pure deterministic CPCB IND-AQI calculator implementing official 2014 Central Pollution Control Board piecewise continuous linear equations with half-up rounding.
  - `risk_scoring.py`: Multi-factor explainable exposure risk engine modeling chemical compounding and atmospheric stagnation without hallucinated medical claims.
  - `quality.py`: Validates plausible bounds, detects provider-calibrated staleness (Open-Meteo: 90m, OpenAQ: 120m, CPCB: 180m), validates coordinates, and normalizes gas units at Standard Reference Conditions ($25^\circ\text{C}, 1013.25\text{ hPa}$) with ambient $T/P$ dynamic adjustment.
