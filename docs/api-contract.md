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

**Response (200 OK):**
```json
{
  "query_location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "city": "Delhi",
    "country": "India"
  },
  "search_radius_km": 25.0,
  "nearest_station": {
    "station_id": "DEMO-DELHI-001",
    "station_name": "Anand Vihar, New Delhi [DEMO FIXTURE]",
    "provider": "DPCC Demo Sensor Feed",
    "location": {
      "latitude": 28.6508,
      "longitude": 77.3152,
      "city": "Delhi",
      "country": "India"
    },
    "distance_km": 11.2,
    "available_pollutants": ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3", "NH3"],
    "data_source_type": "DEMO_FIXTURE",
    "is_active": true
  },
  "nearby_stations": [ ... ],
  "message": "Discovered 2 station(s) within 25.0 km."
}
```

---

### `GET /api/v1/stations/nearby`
Returns a list of monitoring stations near coordinates sorted by Haversine distance.

**Query Parameters:**
- `lat` (float, required): Latitude.
- `lon` (float, required): Longitude.
- `radius_km` (float, optional, default: `25.0`): Radius in km.
- `include_demo` (bool, optional, default: `true`): Include clearly labeled demo fixtures.

**Response (200 OK):** `List[MonitoringStationSummary]`

---

### `GET /api/v1/stations/{station_id}`
Retrieves metadata for a specific station by ID.

**Response (200 OK):** `MonitoringStationSummary`
**Response (404 Not Found):** `{"detail": "Monitoring station not found."}`

---

## 2. Air Quality Telemetry & Providers

### `GET /api/v1/air/current`
Retrieves current environmental measurements, calculates CPCB IND-AQI, and computes explainable exposure risk.

**Query Parameters:**
- `station_id` (string, optional): Specific station ID.
- `lat` (float, optional): User latitude (required if `station_id` omitted).
- `lon` (float, optional): User longitude (required if `station_id` omitted).

**Response (200 OK):**
```json
{
  "observation": {
    "station_id": "DEMO-DELHI-001",
    "station_name": "Anand Vihar, New Delhi [DEMO FIXTURE]",
    "location": { "latitude": 28.6508, "longitude": 77.3152, "country": "India" },
    "timestamp": "2026-11-16T00:30:00Z",
    "provider": "DPCC Demo Sensor Feed",
    "data_source_type": "DEMO_FIXTURE",
    "pm2_5": 185.0,
    "pm10": 310.0,
    "no2": 95.0,
    "temperature_celsius": 19.5,
    "relative_humidity_pct": 82.0,
    "wind_speed_kmh": 4.2
  },
  "station": { ... },
  "distance_from_query_km": 3.4,
  "aqi_result": {
    "standard": "CPCB_INDIA",
    "status": "VALID",
    "overall_aqi": 350,
    "category": "Very Poor",
    "color_code": "#FF0000",
    "prominent_pollutant": "PM2.5",
    "sub_indices": { ... },
    "health_advisory": { ... }
  },
  "risk_assessment": {
    "risk_score": 78,
    "risk_level": "VERY_HIGH",
    "risk_summary": "Very high toxic pollutant burden...",
    "breakdown": [ ... ],
    "activity_recommendations": [ ... ]
  },
  "data_freshness_minutes": 15.0,
  "is_stale": false
}
```

---

### `GET /api/v1/air/history`
Returns chronological observation history for a station.

**Query Parameters:**
- `station_id` (string, required): Station ID.
- `hours` (int, optional, default: `24`): History duration in hours ($1$ to $168$).

**Response (200 OK):**
```json
{
  "station_id": "DEMO-DELHI-001",
  "station_name": "Anand Vihar",
  "provider": "DPCC",
  "data_source_type": "HISTORICAL",
  "count": 24,
  "observations": [ ... ]
}
```

---

### `GET /api/v1/air/providers/status`
Returns live health and telemetry of all integrated providers.

**Response (200 OK):**
```json
{
  "providers": [
    {
      "name": "openaq",
      "display_name": "OpenAQ Global Monitoring Network (v3)",
      "status": "ONLINE",
      "requires_api_key": true,
      "is_authenticated": true,
      "primary_data_type": "LIVE",
      "supported_pollutants": ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"],
      "attribution": "Air quality data courtesy of OpenAQ Community.",
      "latency_ms": 115.2
    },
    {
      "name": "open_meteo",
      "display_name": "Open-Meteo Air Quality (Atmospheric Model)",
      "status": "ONLINE",
      "requires_api_key": false,
      "is_authenticated": true,
      "primary_data_type": "ESTIMATED",
      "supported_pollutants": ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"],
      "attribution": "Data provided by Open-Meteo.com under CC Attribution.",
      "latency_ms": 85.0
    }
  ],
  "active_count": 2,
  "timestamp": "2026-11-16T00:45:00Z"
}
```

---

## 3. Core Calculation & Diagnostics

- `POST /api/v1/aqi/calculate`: Deterministic calculation from an arbitrary `EnvironmentalObservationInput`.
- `GET /api/v1/aqi/demo-fixtures`: Explicit synthetic fixtures for testing.
- `GET /api/v1/health`: Basic service status.
