# AIRGUARD AI — API SPECIFICATION & DATA CONTRACTS

Base URL Prefix: `/api/v1`

---

## 1. Location & Station Discovery

### `GET /api/v1/locations/nearby`
Discovers monitoring stations within a geographic radius of the query coordinates.

**Query Parameters:**
- `lat` (float, required): Latitude in decimal degrees ($-90.0$ to $90.0$).
- `lon` (float, required): Longitude in decimal degrees ($-180.0$ to $180.0$).
- `radius_km` (float, optional, default: `25.0`): Search radius in kilometers.

---

### `GET /api/v1/stations/nearby`
Returns a list of monitoring stations near coordinates sorted by Haversine distance.

---

### `GET /api/v1/stations/{station_id}`
Returns full telemetry, metadata, and status for a specific station identifier.

---

## 2. Environmental Assessment & Air Quality

### `GET /api/v1/air/current`
Returns the verified current environmental assessment including deterministic CPCB AQI and explainable multi-pollutant exposure risk score.

**Query Parameters (one set required):**
- `station_id` (string, optional): Specific station identifier.
- `lat` & `lon` (float, optional): GPS coordinates for nearest station resolution.

---

### `GET /api/v1/air/providers/status`
Returns real-time operational status, latencies, and connectivity telemetry across all ingestion adapters.

---

## 3. Milestone 3: Time-Series Forecasting & AI Explanations

### `GET /api/v1/forecast/current`
Returns multi-horizon time-series predictions (+1h, +3h, +6h, +12h, +24h) with 95% and 90% empirical prediction intervals and deterministic forecast CPCB AQI.

**Query Parameters:**
- `station_id` (string, optional): Specific station ID.
- `lat` & `lon` (float, optional): User coordinates.

**Response Schema (`ForecastCurrentResponse`):**
```json
{
  "status": "ACTIVE",
  "station_id": "DELHI-CAAQMS-01",
  "station_name": "Lodhi Road CAAQMS [PHYSICAL STATION]",
  "data_source_type": "PHYSICAL_STATION",
  "base_timestamp": "2026-11-16T01:00:00Z",
  "forecasts": [
    {
      "horizon_hours": 1,
      "target_timestamp": "2026-11-16T02:00:00Z",
      "predicted_aqi": 235,
      "predicted_aqi_category": "Poor",
      "predicted_aqi_color": "#FB923C",
      "predicted_aqi_prominent_pollutant": "PM2.5",
      "is_cpcb_aqi_valid": true,
      "pollutant_predictions": {
        "PM2.5": {
          "pollutant": "PM2.5",
          "unit": "µg/m³",
          "predicted_value": 118.5,
          "ci95_lower": 99.1,
          "ci95_upper": 137.9,
          "ci90_lower": 102.2,
          "ci90_upper": 134.8
        },
        "PM10": {
          "pollutant": "PM10",
          "unit": "µg/m³",
          "predicted_value": 210.0,
          "ci95_lower": 178.0,
          "ci95_upper": 242.0
        }
      },
      "temperature_celsius": 18.2,
      "relative_humidity_pct": 84.0,
      "wind_speed_kmh": 4.5
    }
  ],
  "model_metadata": {
    "model_type": "AUTOREGRESSIVE_RIDGE",
    "training_sample_count": 72,
    "evaluation_period_start": "2026-11-13T01:00:00Z",
    "evaluation_period_end": "2026-11-16T01:00:00Z",
    "mae_pm25": 11.2,
    "rmse_pm25": 15.4,
    "persistence_mae_pm25": 18.6
  },
  "disclaimer": "Statistical time-series projection. Real conditions may deviate due to unmodeled emission shocks."
}
```

---

### `GET /api/v1/forecast/accuracy`
Returns out-of-sample benchmark comparison (MAE, RMSE) of the Autoregressive Ridge model against Persistence and Seasonal Naive baselines across every forecast horizon (+1h, +3h, +6h, +12h, +24h).

---

### `GET /api/v1/forecast/model/status`
Returns metadata regarding the active forecasting pipeline, training sample volume, feature dimensions, and retraining eligibility.

---

### `POST /api/v1/ai/explain`
Generates grounded environmental and atmospheric explanations answering six structured dimensions without calculating AQI or generating medical claims.

**Request Body (`AIExplanationRequest`):**
```json
{
  "station_id": "DELHI-CAAQMS-01",
  "station_name": "Lodhi Road CAAQMS",
  "latitude": 28.61,
  "longitude": 77.20,
  "data_source_type": "PHYSICAL_STATION",
  "provider": "CPCB / DPCC",
  "observation_timestamp": "2026-11-16T01:00:00Z",
  "overall_aqi": 240,
  "aqi_category": "Poor",
  "prominent_pollutant": "PM2.5",
  "pollutant_sub_indices": { "PM2.5": 240, "PM10": 180, "NO2": 65 },
  "pollutant_concentrations": { "PM2.5": 125.0, "PM10": 210.0, "NO2": 52.0 },
  "temperature_celsius": 19.0,
  "relative_humidity_pct": 82.0,
  "wind_speed_kmh": 4.2,
  "exposure_risk_score": 68,
  "exposure_risk_level": "HIGH",
  "risk_primary_driver": "PM2.5",
  "historical_24h_avg_aqi": 215
}
```

**Response Schema (`AIExplanationResponse`):**
```json
{
  "status": "SUCCESS",
  "provider_used": "deterministic_expert_system",
  "station_name": "Lodhi Road CAAQMS",
  "observation_timestamp": "2026-11-16T01:00:00Z",
  "overall_aqi": 240,
  "aqi_category": "Poor",
  "prominent_pollutant": "PM2.5",
  "atmospheric_dynamics": "Atmospheric boundary layer compression and low nocturnal surface wind speeds (4.2 km/h) restrict vertical convective mixing.",
  "primary_driver_analysis": "Fine particulate matter (PM2.5) at 125.0 µg/m³ is the dominant driver, registering the highest sub-index (240) among all active pollutants.",
  "elevationCauses": "Low surface ventilation combined with urban combustion emissions and relative humidity (82%) promotes particulate hygroscopic growth.",
  "activity_implications": "Poor air quality indicates potential respiratory discomfort for prolonged outdoor physical exertion.",
  "practical_precautions": "Consider limiting strenuous outdoor morning activity; keep residential windows closed during calm hours; use particulate-filtering respirators (N95/FFP2).",
  "historical_comparison": "Current AQI (240) is elevated by approximately 11.6% compared to the 24-hour historical baseline (215).",
  "disclaimer": "Informational environmental interpretation only. Does not constitute medical diagnosis or individual clinical guidance."
}
```

---

### `GET /api/v1/history/availability`
Audits persistent historical observation records, reporting record counts, date ranges, completeness, and strict separation between physical stations, model estimates, and synthetic fixtures.
