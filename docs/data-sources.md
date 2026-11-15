# AIRGUARD AI — DATA SOURCES & PROVIDER SPECIFICATIONS

This document outlines all external data providers integrated into the AirGuard AI platform, their authentication requirements, legal attributions, data provenance classifications, and operational verification status.

---

## 1. Provider Overview & Verification Status

| Provider | Data Source Type | Auth Required | Refresh Cadence | Staleness Threshold | Verification Status | Supported Pollutants |
|---|---|---|---|---|---|---|
| **OpenAQ API v3** | `LIVE` | Yes (`X-API-Key`) | 15–60 min | **120 min** | **UNVERIFIED (LIVE)** / **VERIFIED (MOCKED)** | PM2.5, PM10, NO2, SO2, CO, O3 |
| **Open-Meteo Air Quality** | `ESTIMATED` / `FORECAST` | No (Open access) | 60 min | **90 min** | **VERIFIED (LIVE & MOCKED)** | PM2.5, PM10, NO2, SO2, CO, O3 |
| **CPCB / data.gov.in** | `LIVE` | Yes (`api-key`) | 60–120 min | **180 min** | **UNVERIFIED (LIVE)** / **VERIFIED (MOCKED)** | PM2.5, PM10, NO2, SO2, CO, O3, NH3 |
| **AirGuard Demo Fixtures** | `DEMO_FIXTURE` | No | Static | **120 min** | **VERIFIED** | PM2.5, PM10, NO2, SO2, CO, O3, NH3 |

---

## 2. Detailed Provider Specifications & Audit Results

### A. OpenAQ API v3
- **Official Documentation**: https://docs.openaq.org/
- **Base URL**: `https://api.openaq.org/v3`
- **Authentication**: Passes an API key via the HTTP header `X-API-Key: <OPENAQ_API_KEY>`.
- **Live Verification Status**:
  - Live probe against `https://api.openaq.org/v3/locations?limit=1` confirms OpenAQ v3 mandates an API key: returns `HTTP 401 Unauthorized: {"message": "Unauthorized. A valid API key must be provided in the X-API-Key header."}` when key is absent.
  - When `OPENAQ_API_KEY` is not present in the local environment, the provider cleanly reports `ProviderHealth.UNAUTHENTICATED` with `is_authenticated=False`.
  - **Audit Classification**: In strict compliance with data integrity guidelines, live authenticated retrieval from OpenAQ remains **UNVERIFIED** until an API key is configured in the environment. Adapter code, error handling (401, 403, 429), and sensor discovery are fully verified via automated tests.
- **Data Provenance**: Categorized as `LIVE` ground station measurements.
- **Attribution**: *"Air quality data courtesy of OpenAQ Community & Global EPA/CPCB Feeds."*

### B. Open-Meteo Air Quality API
- **Official Documentation**: https://open-meteo.com/en/docs/air-quality-api
- **Base URL**: `https://air-quality-api.open-meteo.com/v1/air-quality`
- **Authentication**: No API key required for non-commercial open access.
- **Live Verification Status**: **VERIFIED (LIVE)**
  - Successfully connected live to `https://air-quality-api.open-meteo.com/v1/air-quality?latitude=28.6139&longitude=77.2090&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone` (HTTP 200).
  - Verified live returned payload: `interval: 3600`, `pm10: 153.2 µg/m³`, `pm2_5: 136.4 µg/m³`, `carbon_monoxide: 2582.0 µg/m³`, `nitrogen_dioxide: 62.3 µg/m³`, `sulphur_dioxide: 55.5 µg/m³`, `ozone: 18.0 µg/m³`.
  - Verified weather parameter integration via `https://api.open-meteo.com/v1/forecast`: temperature, relative humidity, wind speed, and surface pressure.
- **Data Provenance**:
  - Current model readings are strictly categorized as `ESTIMATED`.
  - Hourly future model steps are strictly categorized as `FORECAST`.
  - Hourly past steps are categorized as `HISTORICAL`.
  - **Data Integrity Mandate**: Model-derived data is never presented as `LIVE` ground station observations.
- **Unit Normalization**:
  - Open-Meteo reports $CO$ in $\mu g/m^3$ ($2,582.0\ \mu g/m^3$).
  - AirGuard AI's Data Quality Engine converts $CO$ to $mg/m^3$ ($2.58\ mg/m^3$), correctly matching CPCB standard units.
- **Attribution**: *"Data provided by Open-Meteo.com under Non-Commercial / Attribution Creative Commons."*

### C. CPCB / Indian Government Data (data.gov.in)
- **Official Portal**: https://data.gov.in/
- **Public Dashboard Investigation**:
  - CPCB's public consumer dashboard at `airquality.cpcb.gov.in` uses internal session tokens and anti-automation protections; it does not offer a supported, public open developer REST API.
  - The official, legally supported API access path for Indian air quality is the Open Government Data (OGD) platform at `data.gov.in`.
- **Resource ID**: `3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69` (Real-Time Air Quality Index from Continuous Ambient Air Quality Monitoring Stations - CAAQMS).
- **Authentication**: Requires a registered developer key (`DATAGOVIN_API_KEY`) passed via query parameter `?api-key=<KEY>&format=json`.
- **Live Verification Status**: When no key is configured in the environment, the provider status transitions to `UNAUTHENTICATED` without interrupting service for other providers. Live retrieval is **UNVERIFIED** pending API credentials.
- **Attribution**: *"National Air Quality Monitoring Programme (NAMP/CAAQMS), Central Pollution Control Board via data.gov.in."*

---

## 3. Data Freshness & Staleness Rules
1. **Freshness Tracking**: Each observation preserves the original provider timestamp (`observation_timestamp`).
2. **Provider-Specific Staleness Thresholds**:
   - Open-Meteo: **90 minutes** (1-hour model runs).
   - OpenAQ v3: **120 minutes** (hourly station feeds).
   - CPCB / data.gov.in: **180 minutes** (CAAQMS ingestion/validation buffer).
3. **Caching**:
   - Station metadata is cached for **1 hour** (`CACHE_STATIONS_TTL_SECONDS = 3600`).
   - Observations are cached for **15 minutes** (`CACHE_OBSERVATIONS_TTL_SECONDS = 900`).
   - Provider health is cached for **5 minutes** (`CACHE_PROVIDER_STATUS_TTL_SECONDS = 300`).
