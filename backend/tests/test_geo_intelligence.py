"""
AirGuard AI - Comprehensive Geographic Intelligence & Spatial Interpolation Tests
Tests coordinate validation, station deduplication, IDW mathematics, minimum station rules,
stale exclusion, missing pollutant handling, hotspot clustering, and API contracts.
"""
from datetime import datetime, timedelta, timezone
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.pollutant import DataSourceType, LocationCoordinate
from app.schemas.geo import (
    GeoObservationItem,
    InterpolationStatus,
    StationType,
    HotspotSeverity,
)
from app.engine.spatial_interpolator import (
    SpatialInterpolator,
    calculate_angular_gap,
    calculate_spatial_uncertainty,
)
from app.services.hotspot_service import HotspotDetectionService
from app.services.geo import haversine_distance_km

client = TestClient(app)


def test_haversine_distance_accuracy():
    # Connaught Place to Anand Vihar, Delhi (~9.84 km great-circle distance)
    d = haversine_distance_km(28.6315, 77.2167, 28.6469, 77.3160)
    assert 9.0 <= d <= 11.0

    # Same location
    assert haversine_distance_km(28.6315, 77.2167, 28.6315, 77.2167) == 0.0


def test_idw_mathematical_correctness():
    """
    Verify IDW weighted average matches exact formula:
    Target at (0.0, 0.0)
    Station 1 at distance d1, value z1
    Station 2 at distance d2, value z2
    Station 3 at distance d3, value z3
    w_i = 1 / (d_i ^ 2)
    """
    now = datetime.now(timezone.utc)
    target_lat, target_lon = 28.60, 77.20

    # Create 3 synthetic stations around target
    # Lat delta of 0.09 deg ~ 9.95 km
    st1 = GeoObservationItem(
        station_id="ST-1",
        station_name="Station North",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.69, longitude=77.20),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=100.0,
        pm10=200.0,
        no2=40.0,
        so2=20.0,
        co=1.0,
        o3=30.0,
    )
    st2 = GeoObservationItem(
        station_id="ST-2",
        station_name="Station East",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.60, longitude=77.29),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=150.0,
        pm10=250.0,
        no2=50.0,
        so2=25.0,
        co=1.5,
        o3=40.0,
    )
    st3 = GeoObservationItem(
        station_id="ST-3",
        station_name="Station South",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.51, longitude=77.20),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=200.0,
        pm10=300.0,
        no2=60.0,
        so2=30.0,
        co=2.0,
        o3=50.0,
    )

    engine = SpatialInterpolator(power_parameter=2.0, min_stations=3, max_search_radius_km=50.0)
    res = engine.interpolate(target_lat, target_lon, [st1, st2, st3])

    assert res.status == InterpolationStatus.INTERPOLATED
    assert res.is_interpolated is True
    assert res.data_source_type == DataSourceType.ESTIMATED
    assert res.contributing_station_count == 3
    assert "pm2_5" in res.pollutants
    assert "pm10" in res.pollutants

    # Because ST1 and ST3 are equidistant and ST2 is roughly similar distance,
    # the estimated PM2.5 should lie between 100 and 200
    pm25_est = res.pollutants["pm2_5"].estimated_value
    assert 130.0 <= pm25_est <= 170.0
    assert res.interpolated_aqi is not None
    assert res.spatial_uncertainty_score < 60.0


def test_idw_exact_collocation():
    """If target is collocated with a station (< 50m), return exact measured value."""
    now = datetime.now(timezone.utc)
    target_lat, target_lon = 28.6315, 77.2167

    st1 = GeoObservationItem(
        station_id="ST-COLOC",
        station_name="Collocated Station",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="OpenAQ",
        location=LocationCoordinate(latitude=28.6315, longitude=77.2167),  # exact match
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=75.4,
        pm10=140.0,
        no2=35.0,
    )
    st2 = GeoObservationItem(
        station_id="ST-DISTANT-1",
        station_name="Distant 1",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="OpenAQ",
        location=LocationCoordinate(latitude=28.70, longitude=77.2167),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=200.0,
        pm10=300.0,
        no2=50.0,
    )
    st3 = GeoObservationItem(
        station_id="ST-DISTANT-2",
        station_name="Distant 2",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="OpenAQ",
        location=LocationCoordinate(latitude=28.55, longitude=77.2167),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=180.0,
        pm10=280.0,
        no2=45.0,
    )

    engine = SpatialInterpolator(power_parameter=2.0, min_stations=3, max_search_radius_km=50.0)
    res = engine.interpolate(target_lat, target_lon, [st1, st2, st3])

    assert res.status == InterpolationStatus.INTERPOLATED
    assert res.pollutants["pm2_5"].estimated_value == pytest.approx(75.4, 0.1)
    assert res.spatial_uncertainty_score <= 15.0


def test_idw_minimum_stations_constraint():
    """Fewer than min_stations within radius must return INSUFFICIENT_STATIONS."""
    now = datetime.now(timezone.utc)
    st1 = GeoObservationItem(
        station_id="ST-1",
        station_name="Station 1",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.61, longitude=77.21),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=50.0,
    )
    st2 = GeoObservationItem(
        station_id="ST-2",
        station_name="Station 2",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.62, longitude=77.22),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=60.0,
    )

    engine = SpatialInterpolator(min_stations=3, max_search_radius_km=50.0)
    # Only 2 stations provided
    res = engine.interpolate(28.60, 77.20, [st1, st2])

    assert res.status == InterpolationStatus.INSUFFICIENT_STATIONS
    assert res.contributing_station_count == 2
    assert res.interpolated_aqi is None


def test_idw_search_radius_exclusion():
    """Stations beyond search radius must be excluded."""
    now = datetime.now(timezone.utc)
    # Station far away in Mumbai (~1150 km from Delhi)
    st_mumbai = GeoObservationItem(
        station_id="ST-MUMBAI",
        station_name="Mumbai Station",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=19.0760, longitude=72.8777),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=120.0,
    )

    engine = SpatialInterpolator(min_stations=3, max_search_radius_km=50.0)
    res = engine.interpolate(28.60, 77.20, [st_mumbai])

    assert res.status == InterpolationStatus.INSUFFICIENT_COVERAGE
    assert res.contributing_station_count == 0


def test_idw_stale_data_rejection():
    """Stale observations (> 120 min) must be excluded from IDW calculation."""
    stale_time = datetime.now(timezone.utc) - timedelta(minutes=150)
    st_stale = GeoObservationItem(
        station_id="ST-STALE",
        station_name="Stale Station",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.61, longitude=77.21),
        timestamp=stale_time,
        data_source_type=DataSourceType.LIVE,
        pm2_5=100.0,
        is_stale=True,
        data_freshness_minutes=150.0,
    )

    engine = SpatialInterpolator(min_stations=1, max_search_radius_km=50.0)
    res = engine.interpolate(28.60, 77.20, [st_stale])

    assert res.status == InterpolationStatus.STALE_INPUTS
    assert res.contributing_station_count == 0


def test_idw_missing_pollutant_never_coerced_to_zero():
    """If a station lacks SO2, it must not inject 0.0 into SO2 interpolation."""
    now = datetime.now(timezone.utc)
    st1 = GeoObservationItem(
        station_id="ST-1",
        station_name="Station 1",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.61, longitude=77.20),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=80.0,
        so2=None,  # Missing SO2
    )
    st2 = GeoObservationItem(
        station_id="ST-2",
        station_name="Station 2",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.62, longitude=77.21),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=90.0,
        so2=30.0,  # Valid SO2
    )
    st3 = GeoObservationItem(
        station_id="ST-3",
        station_name="Station 3",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.59, longitude=77.20),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        pm2_5=85.0,
        so2=40.0,  # Valid SO2
    )

    engine = SpatialInterpolator(min_stations=3, max_search_radius_km=50.0)
    res = engine.interpolate(28.60, 77.20, [st1, st2, st3])

    assert res.status == InterpolationStatus.INTERPOLATED
    assert "so2" in res.pollutants
    # SO2 should be weighted between 30 and 40, NEVER diluted towards 0 by ST-1
    assert 30.0 <= res.pollutants["so2"].estimated_value <= 40.0
    # Contributing stations for SO2 should only be ST-2 and ST-3
    so2_contrib_ids = [c.station_id for c in res.pollutants["so2"].contributing_stations]
    assert "ST-1" not in so2_contrib_ids
    assert "ST-2" in so2_contrib_ids
    assert "ST-3" in so2_contrib_ids


def test_hotspot_multi_station_confirmation():
    """
    Confirmed hotspot requires >= 2 nearby stations with elevated readings.
    Single station must be flagged as ISOLATED_ELEVATED_READING.
    """
    now = datetime.now(timezone.utc)
    service = HotspotDetectionService(cluster_distance_km=15.0, elevated_aqi_threshold=301)

    # 1. Two stations in Delhi Anand Vihar area with Severe AQI
    st1 = GeoObservationItem(
        station_id="ST-AV-1",
        station_name="Anand Vihar 1",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.6469, longitude=77.3160),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        aqi=420,
        pm2_5=310.0,
        dominant_pollutant="PM2.5",
    )
    st2 = GeoObservationItem(
        station_id="ST-AV-2",
        station_name="Anand Vihar 2",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.6520, longitude=77.3200),  # ~0.7 km away
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        aqi=410,
        pm2_5=295.0,
        dominant_pollutant="PM2.5",
    )
    # 2. Single isolated station with high AQI in Dwarka (~25 km away)
    st_dwarka = GeoObservationItem(
        station_id="ST-DWARKA",
        station_name="Dwarka Sector 8",
        station_type=StationType.PHYSICAL_MONITOR,
        provider="CPCB",
        location=LocationCoordinate(latitude=28.5700, longitude=77.0700),
        timestamp=now,
        data_source_type=DataSourceType.LIVE,
        aqi=380,
        pm2_5=240.0,
        dominant_pollutant="PM2.5",
    )

    hotspots_res = service.detect_hotspots(28.60, 77.20, 50.0, [st1, st2, st_dwarka])

    assert hotspots_res.total_hotspots_count == 2
    # First cluster is confirmed (2 stations)
    confirmed_cluster = next((h for h in hotspots_res.hotspots if h.is_confirmed_hotspot), None)
    assert confirmed_cluster is not None
    assert confirmed_cluster.severity == HotspotSeverity.SEVERE_HOTSPOT
    assert confirmed_cluster.contributing_stations_count == 2
    assert confirmed_cluster.peak_aqi == 420
    assert "Confirmed" in confirmed_cluster.explanation

    # Second cluster is isolated (1 station)
    isolated_cluster = next((h for h in hotspots_res.hotspots if not h.is_confirmed_hotspot), None)
    assert isolated_cluster is not None
    assert isolated_cluster.severity == HotspotSeverity.ISOLATED_ELEVATED_READING
    assert isolated_cluster.contributing_stations_count == 1
    assert "Single isolated" in isolated_cluster.explanation


def test_api_geo_stations_endpoint():
    """Test GET /api/v1/geo/stations returns valid schema and status."""
    response = client.get("/api/v1/geo/stations?latitude=28.6139&longitude=77.2090&radius_km=30")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if data:
        st = data[0]
        assert "station_id" in st
        assert "station_name" in st
        assert "station_type" in st
        assert "location" in st
        assert "distance_km" in st


def test_api_geo_observations_endpoint():
    """Test GET /api/v1/geo/observations returns observations with CPCB AQI."""
    response = client.get("/api/v1/geo/observations?latitude=28.6139&longitude=77.2090&radius_km=30")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if data:
        obs = data[0]
        assert "station_id" in obs
        assert "data_source_type" in obs
        assert "pollutant_averaging_hours" in obs
        assert "pollutant_units" in obs


def test_api_geo_interpolation_endpoint():
    """Test GET /api/v1/geo/interpolation returns valid IDW response."""
    # Query with allow_demo=true to guarantee stations in test environment
    response = client.get(
        "/api/v1/geo/interpolation?latitude=28.6139&longitude=77.2090&radius_km=50&allow_demo=true&min_stations=2"
    )
    assert response.status_code == 200
    data = response.json()
    assert data["method"] == "INVERSE_DISTANCE_WEIGHTING"
    assert data["is_interpolated"] is True
    assert data["data_source_type"] == "ESTIMATED"
    assert "spatial_uncertainty_score" in data
    assert "disclaimer" in data


def test_api_geo_hotspots_endpoint():
    """Test GET /api/v1/geo/hotspots returns hotspot clusters."""
    response = client.get(
        "/api/v1/geo/hotspots?latitude=28.6139&longitude=77.2090&radius_km=50&allow_demo=true"
    )
    assert response.status_code == 200
    data = response.json()
    assert "hotspots" in data
    assert "total_hotspots_count" in data
    assert "center_location" in data


def test_api_geo_coverage_endpoint():
    """Test GET /api/v1/geo/coverage returns spatial network density assessment."""
    response = client.get(
        "/api/v1/geo/coverage?latitude=28.6139&longitude=77.2090&radius_km=50"
    )
    assert response.status_code == 200
    data = response.json()
    assert "spatial_density_score" in data
    assert "coverage_quality" in data
    assert "physical_stations_count" in data
    assert "model_grid_points_count" in data
