# AIRGUARD AI — DATA SOURCES & PROVIDER SPECIFICATIONS

This document outlines all external data providers integrated into the AirGuard AI platform, their authentication requirements, legal attributions, data provenance classifications, and operational characteristics.

---

## 1. Provider Overview

| Provider | Data Source Type | Auth Required | Refresh Interval | Supported Pollutants |
|---|---|---|---|---|
| **OpenAQ API v3** | `LIVE` | Yes (`X-API-Key`) | 15–60 minutes | PM2.5, PM10, NO2, SO2, CO, O3 |
| **Open-Meteo Air Quality** | `ESTIMATED` / `FORECAST` | No (Open access) | 60 minutes | PM2.5, PM10, NO2, SO2, CO, O3 |
| **CPCB / data.gov.in** | `LIVE` | Yes (`api-key`) | 60 minutes | PM2.5, PM10, NO2, SO2, CO, O3, NH3 |
| **AirGuard Demo Fixtures** | `DEMO_FIXTURE` | No | Static | PM2.5, PM10, NO2, SO2, CO, O3, NH3 |

---

## 2. Detailed Provider Specifications

### A. OpenAQ API v3
- **Official Documentation**: https://docs.openaq.org/
- **Base URL**: `https://api.openaq.org/v3`
- **Authentication**: Passes an API key via the HTTP header `X-API-Key: <OPENAQ_API_KEY>`.
- **Key Capabilities**:
  - `GET /locations?coordinates={lat},{lon}&radius={meters}`: Discovers nearby physical monitoring stations.
  - `GET /locations/{id}`: Detailed station metadata.
  - `GET /locations/{id}/latest`: Latest pollutant sensor measurements.
- **Data Provenance**: Categorized as `LIVE` ground station measurements.
- **Attribution**: *"Air quality data courtesy of OpenAQ Community & Global EPA/CPCB Feeds."*
- **Known Limitations**:
  - Free API tier enforces rate limits (HTTP 429). The AirGuard AI backend handles this with backoff and in-memory TTL caching.
  - Not every station monitors all 8 criteria pollutants. Missing parameters are maintained as `null` and never fabricated.

### B. Open-Meteo Air Quality API
- **Official Documentation**: https://open-meteo.com/en/docs/air-quality-api
- **Base URL**: `https://air-quality-api.open-meteo.com/v1/air-quality`
- **Authentication**: No API key required for non-commercial open tier.
- **Model Grounding**: Combines regional Eulerian chemical transport models (CAMS, SILAM, EMEP) with 11 km resolution.
- **Data Provenance**:
  - `current` model readings are strictly categorized as `ESTIMATED`.
  - `hourly` future values are strictly categorized as `FORECAST`.
  - **Data Integrity Mandate**: Model-derived data is never presented as `LIVE` ground station observations.
- **Unit Normalization**:
  - Open-Meteo provides Carbon Monoxide ($CO$) in $\mu g/m^3$.
  - AirGuard AI's Data Quality Engine automatically converts $CO$ to $mg/m^3$ ($1 \ mg/m^3 = 1000 \ \mu g/m^3$) per CPCB standards.
- **Attribution**: *"Data provided by Open-Meteo.com under Attribution Creative Commons."*

### C. CPCB / Indian Government Data (data.gov.in)
- **Official Portal**: https://data.gov.in/
- **Public Dashboard Investigation**:
  - CPCB's public consumer dashboard at `airquality.cpcb.gov.in` uses internal session tokens and anti-automation protections; it does not offer a supported, public open developer REST API.
  - The official, legally supported API access path for Indian air quality is the Open Government Data (OGD) platform at `data.gov.in`.
- **Resource ID**: `3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69` (Real-Time Air Quality Index from Continuous Ambient Air Quality Monitoring Stations - CAAQMS).
- **Authentication**: Requires a registered developer key (`DATAGOVIN_API_KEY`) passed via query parameter `?api-key=<KEY>&format=json`.
- **Handling Without Key**: When no key is configured in the environment, the provider status transitions to `UNAUTHENTICATED` without interrupting service for other providers.
- **Attribution**: *"National Air Quality Monitoring Programme (NAMP/CAAQMS), Central Pollution Control Board via data.gov.in."*

---

## 3. Data Freshness & Staleness Rules
1. **Freshness Tracking**: Each observation preserves the original provider timestamp (`observation_timestamp`).
2. **Staleness Threshold**: Observations older than `DATA_STALE_THRESHOLD_MINUTES` (120 minutes) are flagged with `is_stale: true` and displayed with a warning badge.
3. **Caching**:
   - Station metadata is cached for **1 hour** (`CACHE_STATIONS_TTL_SECONDS = 3600`).
   - Observations are cached for **15 minutes** (`CACHE_OBSERVATIONS_TTL_SECONDS = 900`).
   - Provider health is cached for **5 minutes** (`CACHE_PROVIDER_STATUS_TTL_SECONDS = 300`).
