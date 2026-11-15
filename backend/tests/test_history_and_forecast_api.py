"""
AirGuard AI - API Integration Tests for History, Forecasting, and AI Explainer Endpoints
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.base import init_db

# Ensure tables exist
init_db()


def test_history_availability_endpoint():
    """Verify GET /api/v1/history/availability returns structured dataset breakdown."""
    with TestClient(app) as client:
        response = client.get("/api/v1/history/availability")
        assert response.status_code == 200
        data = response.json()
        assert "total_records" in data
        assert "provenance_breakdown" in data
        assert "pollutant_completeness_pct" in data
        assert "sufficient_for_ml_training" in data
        assert "active_forecasting_pipeline" in data
        assert data["total_records"] >= 0


def test_forecast_current_endpoint():
    """Verify GET /api/v1/forecast/current returns multi-horizon predictions and forecast AQI."""
    with TestClient(app) as client:
        response = client.get("/api/v1/forecast/current?lat=28.6139&lon=77.2090")
        assert response.status_code == 200
        data = response.json()
        assert "station_id" in data
        assert "model_metadata" in data
        assert "horizons" in data
        horizons = data["horizons"]
        assert len(horizons) == 5  # 1h, 3h, 6h, 12h, 24h
        offsets = [h["horizon_hours"] for h in horizons]
        assert offsets == [1, 3, 6, 12, 24]

        for h in horizons:
            assert h["data_source_type"] == "FORECAST"
            assert "PM2.5" in h["predictions"]
            pm25 = h["predictions"]["PM2.5"]
            assert pm25["point_estimate"] > 0
            assert pm25["interval_95"][0] <= pm25["point_estimate"] <= pm25["interval_95"][1]


def test_forecast_accuracy_endpoint():
    """Verify GET /api/v1/forecast/accuracy returns MAE and RMSE across horizons."""
    with TestClient(app) as client:
        response = client.get("/api/v1/forecast/accuracy")
        assert response.status_code == 200
        data = response.json()
        assert "model_id" in data
        assert "metrics" in data
        metrics = data["metrics"]
        assert len(metrics) > 0
        for m in metrics:
            assert "model_mae" in m
            assert "persistence_mae" in m
            assert "improvement_vs_persistence_pct" in m


def test_forecast_model_status_endpoint():
    """Verify GET /api/v1/forecast/model/status."""
    with TestClient(app) as client:
        response = client.get("/api/v1/forecast/model/status")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "OPERATIONAL"
        assert data["model_type"] == "AUTOREGRESSIVE_RIDGE"
        assert "lag_0" in data["features_used"]


def test_ai_explain_endpoint():
    """Verify POST /api/v1/ai/explain returns structured 6-point atmospheric briefing."""
    payload = {
        "observation": {
            "station_id": "TEST-DELHI-01",
            "station_name": "Test Anand Vihar Station",
            "location": {
                "latitude": 28.65,
                "longitude": 77.31,
                "city": "Delhi",
                "country": "India"
            },
            "timestamp": "2026-11-16T00:30:00Z",
            "provider": "DPCC Live Feed",
            "data_source_type": "LIVE",
            "pm2_5": 165.0,
            "pm10": 280.0,
            "no2": 75.0,
            "temperature_celsius": 17.5,
            "relative_humidity_pct": 82.0,
            "wind_speed_kmh": 4.5
        },
        "aqi_result": {
            "standard": "CPCB_INDIA",
            "status": "VALID",
            "status_message": "Computed successfully",
            "overall_aqi": 335,
            "category": "Very Poor",
            "color_code": "#FF0000",
            "prominent_pollutant": "PM2.5",
            "sub_indices": {},
            "monitored_pollutant_count": 3,
            "has_particulate_matter": True,
            "data_source_type": "LIVE",
            "provider": "DPCC Live Feed",
            "observation_timestamp": "2026-11-16T00:30:00Z",
            "calculation_timestamp": "2026-11-16T00:35:00Z",
            "location": {
                "latitude": 28.65,
                "longitude": 77.31,
                "city": "Delhi",
                "country": "India"
            }
        },
        "historical_24h_avg_pm25": 130.0,
        "historical_trend": "RISING"
    }

    with TestClient(app) as client:
        response = client.post("/api/v1/ai/explain", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "atmospheric_dynamics" in data
        assert "primary_pollutant_driver" in data
        assert "elevation_causes" in data
        assert "outdoor_activity_implication" in data
        assert "practical_precautions" in data
        assert "historical_comparison" in data
        assert "disclaimer" in data
        assert data["is_deterministic_fallback"] is True
