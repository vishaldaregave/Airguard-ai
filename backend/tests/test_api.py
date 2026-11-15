"""
AirGuard AI - API Endpoint Integration Tests
"""
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "operational"
    assert "CPCB IND-AQI" in data["specification"]


def test_health_endpoint():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "CPCB_INDIA_2014" in data["standards"]


def test_calculate_endpoint_success():
    payload = {
        "location": {
            "latitude": 28.6139,
            "longitude": 77.2090,
            "city": "New Delhi",
            "country": "India"
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "provider": "CPCB Official Feed",
        "data_source_type": "LIVE",
        "pm2_5": 140.0,
        "pm10": 260.0,
        "no2": 65.0,
        "temperature_celsius": 22.0,
        "relative_humidity_pct": 60.0,
        "wind_speed_kmh": 10.0
    }
    response = client.post("/api/v1/aqi/calculate", json=payload)
    assert response.status_code == 200
    data = response.json()
    
    assert "aqi_result" in data
    assert "risk_assessment" in data
    
    aqi_res = data["aqi_result"]
    assert aqi_res["status"] == "VALID"
    assert aqi_res["overall_aqi"] is not None
    assert aqi_res["prominent_pollutant"] in ["PM2.5", "PM10"]
    assert aqi_res["category"] in ["Poor", "Very Poor"]
    assert aqi_res["health_advisory"] is not None


def test_calculate_endpoint_insufficient_pollutants():
    payload = {
        "location": {
            "latitude": 28.6139,
            "longitude": 77.2090,
            "city": "New Delhi",
            "country": "India"
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "provider": "CPCB Official Feed",
        "data_source_type": "LIVE",
        "pm2_5": 50.0
        # Missing other pollutants
    }
    response = client.post("/api/v1/aqi/calculate", json=payload)
    assert response.status_code == 200
    data = response.json()
    aqi_res = data["aqi_result"]
    assert aqi_res["status"] == "INSUFFICIENT_POLLUTANTS"
    assert aqi_res["overall_aqi"] is None


def test_demo_fixtures_endpoint():
    response = client.get("/api/v1/aqi/demo-fixtures")
    assert response.status_code == 200
    fixtures = response.json()
    assert len(fixtures) >= 3
    for f in fixtures:
        assert f["data_source_type"] == "DEMO_FIXTURE"
        assert "[DEMO FIXTURE]" in f["station_name"]
