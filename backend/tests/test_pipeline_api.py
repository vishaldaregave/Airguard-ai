"""
AirGuard AI - Integration Tests for Milestone 2 Endpoints
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_locations_nearby_endpoint():
    res = client.get("/api/v1/locations/nearby?lat=28.6139&lon=77.2090&radius_km=25")
    assert res.status_code == 200
    data = res.json()
    assert "query_location" in data
    assert data["query_location"]["latitude"] == 28.6139
    assert "nearby_stations" in data
    assert isinstance(data["nearby_stations"], list)


def test_stations_nearby_endpoint():
    res = client.get("/api/v1/stations/nearby?lat=28.6139&lon=77.2090&radius_km=30")
    assert res.status_code == 200
    stations = res.json()
    assert isinstance(stations, list)
    assert len(stations) > 0
    first = stations[0]
    assert "station_id" in first
    assert "station_name" in first
    assert "data_source_type" in first


def test_station_details_endpoint_demo():
    res = client.get("/api/v1/stations/DEMO-DELHI-001")
    assert res.status_code == 200
    station = res.json()
    assert station["station_id"] == "DEMO-DELHI-001"
    assert station["data_source_type"] == "DEMO_FIXTURE"


def test_station_details_endpoint_not_found():
    res = client.get("/api/v1/stations/NON-EXISTENT-STATION-999")
    assert res.status_code == 404


def test_air_current_endpoint_by_station_id():
    res = client.get("/api/v1/air/current?station_id=DEMO-DELHI-001")
    assert res.status_code == 200
    data = res.json()
    assert "observation" in data
    assert "aqi_result" in data
    assert "risk_assessment" in data
    assert data["observation"]["station_id"] == "DEMO-DELHI-001"
    assert data["aqi_result"]["status"] == "VALID"
    assert data["aqi_result"]["overall_aqi"] is not None


def test_air_current_endpoint_by_coordinates():
    res = client.get("/api/v1/air/current?lat=28.65&lon=77.31")
    assert res.status_code == 200
    data = res.json()
    assert "observation" in data
    assert "aqi_result" in data
    assert "distance_from_query_km" in data


def test_air_current_endpoint_missing_params():
    # Neither station_id nor lat/lon provided
    res = client.get("/api/v1/air/current")
    assert res.status_code == 400


def test_air_history_endpoint():
    res = client.get("/api/v1/air/history?station_id=DEMO-DELHI-001&hours=12")
    assert res.status_code == 200
    data = res.json()
    assert "station_id" in data
    assert "observations" in data
    assert isinstance(data["observations"], list)


def test_providers_status_endpoint():
    res = client.get("/api/v1/air/providers/status")
    assert res.status_code == 200
    data = res.json()
    assert "providers" in data
    assert "active_count" in data
    provider_names = [p["name"] for p in data["providers"]]
    assert "openaq" in provider_names
    assert "open_meteo" in provider_names
    assert "cpcb_datagov" in provider_names
    assert "demo_fixtures" in provider_names
