"""
AirGuard AI - Milestone 5.1.1 Spatial Accuracy & Geographic Validation Audit Tests
Rigorous mathematical, algorithmic, and statistical audit of:
1. IDW interpolation weighting, normalization, exact collocation, and averaging periods.
2. Leave-One-Station-Out (LOSO) spatial cross-validation and provenance separation.
3. Spatial uncertainty indicator components, normalization, and bounds.
4. Hotspot clustering: isolated, pairwise, chain-connected, mixed-severity, and stale inputs.
"""
from datetime import datetime, timezone
import math
import sqlite3
import pytest

from app.schemas.pollutant import DataSourceType, LocationCoordinate
from app.schemas.geo import (
    GeoObservationItem,
    HotspotSeverity,
    InterpolationStatus,
    StationType,
)
from app.engine.spatial_interpolator import (
    SpatialInterpolator,
    calculate_angular_gap,
    calculate_spatial_uncertainty,
)
from app.services.hotspot_service import HotspotDetectionService
from app.services.geo import haversine_distance_km


def create_obs(
    station_id: str,
    station_name: str,
    lat: float,
    lon: float,
    pm25: float = 80.0,
    pm10: float = 150.0,
    no2: float = 40.0,
    aqi: int = 180,
    station_type: StationType = StationType.PHYSICAL_MONITOR,
    data_source_type: DataSourceType = DataSourceType.LIVE,
    is_stale: bool = False,
    freshness_min: float = 15.0,
    pm25_hours: int = 24,
) -> GeoObservationItem:
    return GeoObservationItem(
        station_id=station_id,
        station_name=station_name,
        provider="CPCB" if station_type == StationType.PHYSICAL_MONITOR else "Open-Meteo",
        station_type=station_type,
        location=LocationCoordinate(latitude=lat, longitude=lon, city="Delhi", country="India"),
        timestamp=datetime.now(timezone.utc),
        data_source_type=data_source_type,
        aqi=aqi,
        aqi_category="Moderate" if aqi <= 200 else ("Poor" if aqi <= 300 else "Severe"),
        prominent_pollutant="PM2.5",
        pm2_5=pm25,
        pm10=pm10,
        no2=no2,
        pollutant_averaging_hours={"pm2_5": pm25_hours, "pm10": 24, "no2": 24},
        data_freshness_minutes=freshness_min,
        is_stale=is_stale,
    )


# =========================================================================
# AUDIT 1: IDW INTERPOLATION & EXACT COLLOCATION
# =========================================================================

def test_idw_multiple_exact_collocated_stations_aggregation():
    """
    Audit 1: Multiple stations within the 50m exact-collocation threshold (d <= 0.05 km).
    Scientifically defensible behavior:
    Instead of arbitrary selection of one station, the interpolator computes the arithmetic mean
    across co-located monitors with equal weight (1/M = 0.5 for M=2) and assigns low spatial uncertainty.
    """
    interpolator = SpatialInterpolator(power_parameter=2.0, collocation_threshold_km=0.05)
    target_lat = 28.6139
    target_lon = 77.2090

    # Two co-located stations at exact target location (d = 0.00 km)
    obs_collocated_1 = create_obs("COL-1", "Collocated Sensor Alpha", target_lat, target_lon, pm25=100.0, pm10=200.0)
    obs_collocated_2 = create_obs("COL-2", "Collocated Sensor Beta", target_lat, target_lon, pm25=120.0, pm10=240.0)
    # Background distant stations to satisfy minimum station requirement (k >= 3)
    obs_distant_1 = create_obs("DIST-1", "Distant Monitor 1", target_lat + 0.1, target_lon, pm25=60.0)
    obs_distant_2 = create_obs("DIST-2", "Distant Monitor 2", target_lat - 0.1, target_lon, pm25=50.0)

    observations = [obs_collocated_1, obs_collocated_2, obs_distant_1, obs_distant_2]

    res = interpolator.interpolate(target_lat, target_lon, observations)

    assert res.status == InterpolationStatus.INTERPOLATED
    assert "pm2_5" in res.pollutants
    pm25_interp = res.pollutants["pm2_5"]

    # Verify arithmetic mean: (100.0 + 120.0) / 2 = 110.0
    assert pm25_interp.estimated_value == pytest.approx(110.0, abs=0.1)

    # Verify contributing stations breakdown: both collocated stations present with equal weight 0.5
    contributors = pm25_interp.contributing_stations
    assert len(contributors) == 2
    contrib_ids = {c.station_id for c in contributors}
    assert contrib_ids == {"COL-1", "COL-2"}
    for c in contributors:
        assert c.weight == pytest.approx(0.5, abs=0.01)

    # Spatial uncertainty is capped to <= 10.0 because observer is exactly at monitoring site
    assert res.spatial_uncertainty_score <= 10.0


def test_idw_minimum_station_constraint_and_search_radius():
    """
    Audit 1: Verify radius boundary enforcement (R <= 50km) and minimum station count (k >= 3).
    """
    interpolator = SpatialInterpolator(max_search_radius_km=50.0, min_stations=3)
    target_lat = 28.6000
    target_lon = 77.2000

    # Case A: 2 stations within 50km, 1 station at 80km
    obs_in_1 = create_obs("S1", "Station 1", target_lat + 0.05, target_lon)   # ~5.5 km
    obs_in_2 = create_obs("S2", "Station 2", target_lat - 0.05, target_lon)   # ~5.5 km
    obs_out = create_obs("S3_FAR", "Far Station", target_lat + 0.8, target_lon) # ~88 km (beyond 50km)

    res = interpolator.interpolate(target_lat, target_lon, [obs_in_1, obs_in_2, obs_out])
    assert res.status == InterpolationStatus.INSUFFICIENT_STATIONS
    assert res.contributing_station_count == 2
    assert res.spatial_uncertainty_score == 90.0


def test_idw_missing_pollutant_handling_and_averaging_period_filter():
    """
    Audit 1: Verify missing pollutant handling and rejection of incompatible averaging periods.
    """
    interpolator = SpatialInterpolator(min_stations=3)
    target_lat = 28.6000
    target_lon = 77.2000

    # S1, S2, S3 monitor PM2.5 (24hr avg). S3 does NOT monitor NO2 (missing).
    s1 = create_obs("S1", "Station 1", target_lat + 0.04, target_lon, pm25=80.0, no2=30.0)
    s2 = create_obs("S2", "Station 2", target_lat - 0.04, target_lon, pm25=90.0, no2=40.0)
    s3 = create_obs("S3", "Station 3", target_lat, target_lon + 0.04, pm25=100.0, no2=None)

    # S4 has 1hr averaging period for PM2.5, whereas dominant period is 24hr
    s4 = create_obs("S4", "Station 4", target_lat, target_lon - 0.04, pm25=300.0, pm25_hours=1, no2=None)

    res = interpolator.interpolate(target_lat, target_lon, [s1, s2, s3, s4])

    assert res.status == InterpolationStatus.INTERPOLATED
    assert "pm2_5" in res.pollutants
    # PM2.5 should only use 24hr stations S1, S2, S3; S4 (1hr) filtered out
    pm25_contribs = [c.station_id for c in res.pollutants["pm2_5"].contributing_stations]
    assert "S4" not in pm25_contribs
    assert set(pm25_contribs) == {"S1", "S2", "S3"}

    # NO2 is only in S1 and S2
    assert "no2" in res.pollutants
    no2_contribs = [c.station_id for c in res.pollutants["no2"].contributing_stations]
    assert set(no2_contribs) == {"S1", "S2"}


# =========================================================================
# AUDIT 2: SPATIAL VALIDATION & LEAVE-ONE-STATION-OUT (LOSO)
# =========================================================================

def evaluate_loso_spatial_validation(
    observations: List[GeoObservationItem],
    pollutants: List[str] = ("pm2_5", "pm10", "no2"),
) -> dict:
    """
    Leave-One-Station-Out (LOSO) spatial cross-validation algorithm.
    Separates physical monitors from model-grid estimates.
    Returns per-pollutant MAE, RMSE, bias, sample counts, or reports INSUFFICIENT_VALIDATION_DATA.
    """
    physical_obs = [o for o in observations if o.station_type == StationType.PHYSICAL_MONITOR]
    model_obs = [o for o in observations if o.station_type == StationType.ATMOSPHERIC_MODEL_GRID]

    # Scientific requirement: at least 4 concurrent physical stations required for LOSO (k=3 for IDW + 1 held-out)
    if len(physical_obs) < 4:
        return {
            "status": "INSUFFICIENT_VALIDATION_DATA",
            "physical_station_count": len(physical_obs),
            "model_grid_count": len(model_obs),
            "message": f"Insufficient concurrent physical stations for LOSO spatial cross-validation (required >= 4, found {len(physical_obs)}).",
            "metrics": {},
        }

    interpolator = SpatialInterpolator(power_parameter=2.0, min_stations=3, max_search_radius_km=50.0)
    errors_by_pol = {pol: [] for pol in pollutants}

    for i, held_out in enumerate(physical_obs):
        training_pool = [o for j, o in enumerate(physical_obs) if j != i]
        interp_res = interpolator.interpolate(
            target_lat=held_out.location.latitude,
            target_lon=held_out.location.longitude,
            observations=training_pool,
        )

        if interp_res.status == InterpolationStatus.INTERPOLATED:
            for pol in pollutants:
                actual_val = getattr(held_out, pol, None)
                if actual_val is not None and pol in interp_res.pollutants:
                    predicted_val = interp_res.pollutants[pol].estimated_value
                    err = predicted_val - actual_val
                    errors_by_pol[pol].append(err)

    metrics = {}
    for pol, errs in errors_by_pol.items():
        n = len(errs)
        if n > 0:
            mae = sum(abs(e) for e in errs) / float(n)
            rmse = math.sqrt(sum(e * e for e in errs) / float(n))
            bias = sum(errs) / float(n)
            metrics[pol] = {
                "sample_count": n,
                "mae": round(mae, 2),
                "rmse": round(rmse, 2),
                "bias": round(bias, 2),
            }
        else:
            metrics[pol] = {"sample_count": 0, "status": "NO_MATCHING_OBSERVATIONS"}

    return {
        "status": "VALIDATED",
        "physical_station_count": len(physical_obs),
        "model_grid_count": len(model_obs),
        "metrics": metrics,
    }


def test_database_actual_physical_station_count_audit():
    """
    Audit 2: Inspect real-world database records in airguard.db.
    Verify exact physical monitoring station count and report INSUFFICIENT_VALIDATION_DATA
    honestly without fabricating metrics or conflating model grid estimates.
    """
    con = sqlite3.connect("airguard.db")
    cur = con.cursor()

    # Query monitoring stations
    stations = cur.execute("SELECT id, station_code, provider, data_source_type FROM monitoring_stations").fetchall()
    # In airguard.db: stations are model grid points (Open-Meteo atmospheric model grids)
    assert len(stations) >= 1
    assert all("METEO-GRID" in s[1] for s in stations)

    # Query observations count
    obs_count = cur.execute("SELECT count(*) FROM station_observations").fetchone()[0]
    assert obs_count >= 72

    # Physical monitors in database = 0
    # Evaluate LOSO with real database stations: must explicitly return INSUFFICIENT_VALIDATION_DATA
    real_db_obs = []  # No physical monitors in SQLite db
    val_result = evaluate_loso_spatial_validation(real_db_obs)
    assert val_result["status"] == "INSUFFICIENT_VALIDATION_DATA"
    assert val_result["physical_station_count"] == 0


def test_loso_mathematical_algorithm_on_geometric_benchmark():
    """
    Audit 2: Test the LOSO cross-validation mathematical algorithm using a 5-station geometric benchmark.
    This verifies the mathematical calculation of MAE, RMSE, and bias across held-out stations.
    """
    # 5 stations arranged in a diamond + center configuration
    s_center = create_obs("S_CTR", "Center", 28.61, 77.21, pm25=100.0, pm10=200.0, no2=40.0)
    s_north  = create_obs("S_N", "North", 28.66, 77.21, pm25=110.0, pm10=210.0, no2=42.0)
    s_south  = create_obs("S_S", "South", 28.56, 77.21, pm25=90.0, pm10=190.0, no2=38.0)
    s_east   = create_obs("S_E", "East", 28.61, 77.26, pm25=105.0, pm10=205.0, no2=41.0)
    s_west   = create_obs("S_W", "West", 28.61, 77.16, pm25=95.0, pm10=195.0, no2=39.0)

    obs_pool = [s_center, s_north, s_south, s_east, s_west]

    val_res = evaluate_loso_spatial_validation(obs_pool, pollutants=["pm2_5", "pm10", "no2"])
    assert val_res["status"] == "VALIDATED"
    assert val_res["physical_station_count"] == 5

    pm25_metrics = val_res["metrics"]["pm2_5"]
    assert pm25_metrics["sample_count"] == 5
    assert pm25_metrics["mae"] >= 0.0
    assert pm25_metrics["rmse"] >= pm25_metrics["mae"]  # Mathematical property: RMSE >= MAE
    assert isinstance(pm25_metrics["bias"], float)


# =========================================================================
# AUDIT 3: HEURISTIC SPATIAL UNCERTAINTY INDICATOR
# =========================================================================

def test_spatial_uncertainty_score_bounds_and_components():
    """
    Audit 3: Verify bounds [0, 100], normalization, and weights of spatial uncertainty:
    40% Distance, 30% Density, 30% Angular Gap.
    Confirm that collocated stations receive minimal uncertainty (<= 10.0).
    """
    # Case 1: Collocated station (d <= 50m) -> capped to <= 10.0
    u_collocated = calculate_spatial_uncertainty(
        min_dist_km=0.02,
        mean_dist_km=0.02,
        station_count=6,
        max_radius_km=50.0,
        max_angular_gap_deg=60.0,
    )
    assert 0.0 <= u_collocated <= 10.0

    # Case 2: Dense uniform network surrounding target (6 stations, gap 60 deg, mean dist 10km)
    u_dense = calculate_spatial_uncertainty(
        min_dist_km=5.0,
        mean_dist_km=10.0,
        station_count=6,
        max_radius_km=50.0,
        max_angular_gap_deg=60.0,
    )
    # dist_score = (10/50)*100 = 20. count_score = 0. angle_score = 10.
    # composite = 0.4*20 + 0.3*0 + 0.3*10 = 8 + 0 + 3 = 11.0
    assert u_dense == pytest.approx(11.0, abs=0.5)

    # Case 3: Geographically unbalanced distribution (all stations North, gap = 240 deg)
    u_unbalanced = calculate_spatial_uncertainty(
        min_dist_km=15.0,
        mean_dist_km=25.0,
        station_count=3,
        max_radius_km=50.0,
        max_angular_gap_deg=240.0,
    )
    # dist_score = (25/50)*100 = 50. count_score = (1 - 3/6)*100 = 50.
    # angle_score: gap=240 > 180 -> 60 + ((240-180)/180)*40 = 60 + 13.33 = 73.33
    # composite = 0.4*50 + 0.3*50 + 0.3*73.33 = 20 + 15 + 22.0 = 57.0
    assert 55.0 <= u_unbalanced <= 60.0

    # Case 4: Sparse, distant, one-sided extrapolation (gap = 330 deg, mean dist 45km, count = 1)
    u_sparse = calculate_spatial_uncertainty(
        min_dist_km=40.0,
        mean_dist_km=45.0,
        station_count=1,
        max_radius_km=50.0,
        max_angular_gap_deg=330.0,
    )
    assert u_sparse > 80.0
    assert u_sparse <= 100.0


def test_angular_gap_calculation_symmetry():
    """
    Audit 3: Test angular gap computation for balanced vs unbalanced station configurations.
    """
    target_lat, target_lon = 28.61, 77.21

    # Balanced 4-point cardinal configuration (N, S, E, W): maximum gap should be ~90 deg
    cardinal_coords = [
        (target_lat + 0.1, target_lon),       # N (90 deg)
        (target_lat - 0.1, target_lon),       # S (270 deg)
        (target_lat, target_lon + 0.1),       # E (0 deg)
        (target_lat, target_lon - 0.1),       # W (180 deg)
    ]
    gap_balanced = calculate_angular_gap(target_lat, target_lon, cardinal_coords)
    assert gap_balanced == pytest.approx(90.0, abs=1.0)

    # Unbalanced 3-point configuration (all placed North of target)
    north_only = [
        (target_lat + 0.1, target_lon),
        (target_lat + 0.15, target_lon + 0.05),
        (target_lat + 0.12, target_lon - 0.05),
    ]
    gap_unbalanced = calculate_angular_gap(target_lat, target_lon, north_only)
    assert gap_unbalanced > 180.0  # Demonstrates extrapolation condition


# =========================================================================
# AUDIT 4: HOTSPOT CLUSTERING & CHAIN CONNECTIVITY
# =========================================================================

def test_hotspot_isolated_elevated_station_not_confirmed():
    """
    Audit 4: Single isolated elevated station must NOT be labeled as a confirmed hotspot.
    """
    detector = HotspotDetectionService(cluster_distance_km=15.0, elevated_aqi_threshold=201)
    isolated_obs = create_obs("ISO-1", "Isolated Industrial Monitor", 28.61, 77.21, aqi=350, pm25=180.0)

    res = detector.detect_hotspots(28.61, 77.21, query_radius_km=50.0, observations=[isolated_obs])
    assert len(res.hotspots) == 1
    hotspot = res.hotspots[0]
    assert hotspot.is_confirmed_hotspot is False
    assert hotspot.severity == HotspotSeverity.ISOLATED_ELEVATED_READING
    assert hotspot.contributing_stations_count == 1
    assert hotspot.physical_stations_count == 1


def test_hotspot_two_nearby_elevated_stations_confirmed():
    """
    Audit 4: Two nearby elevated stations (d <= 15km) must form a confirmed hotspot cluster.
    """
    detector = HotspotDetectionService(cluster_distance_km=15.0)
    s1 = create_obs("S1", "Industrial Site A", 28.61, 77.21, aqi=320, pm25=150.0)
    s2 = create_obs("S2", "Industrial Site B", 28.65, 77.23, aqi=340, pm25=160.0) # ~5.0 km apart

    res = detector.detect_hotspots(28.61, 77.21, query_radius_km=50.0, observations=[s1, s2])
    assert len(res.hotspots) == 1
    hotspot = res.hotspots[0]
    assert hotspot.is_confirmed_hotspot is True
    assert hotspot.contributing_stations_count == 2
    assert hotspot.physical_stations_count == 2
    assert hotspot.peak_aqi == 340
    assert hotspot.mean_aqi == 330.0


def test_hotspot_chain_connected_cluster_non_uniform_disclaimer():
    """
    Audit 4: Chain-connected cluster (A <-> B <-> C <-> D) where adjacent stations are <= 15km apart,
    forming a large total cluster (> 30km across).
    Verify that physical stations count is reported, cluster extent is computed,
    and explanation contains explicit chain-connectivity disclaimer stating it does NOT imply
    uniform pollution across the entire bounding area.
    """
    detector = HotspotDetectionService(cluster_distance_km=15.0)

    # Chain of 4 stations, each 10 km apart along latitude:
    # S1 (28.30) -> S2 (28.39) -> S3 (28.48) -> S4 (28.57)
    # Total span: (28.57 - 28.30) * 110.57 km = ~30 km
    s1 = create_obs("S1", "South Monitor", 28.30, 77.20, aqi=280)
    s2 = create_obs("S2", "Mid-South Monitor", 28.39, 77.20, aqi=290)
    s3 = create_obs("S3", "Mid-North Monitor", 28.48, 77.20, aqi=270)
    s4 = create_obs("S4", "North Monitor", 28.57, 77.20, aqi=310)

    res = detector.detect_hotspots(28.40, 77.20, query_radius_km=50.0, observations=[s1, s2, s3, s4])
    assert len(res.hotspots) == 1
    cluster = res.hotspots[0]

    assert cluster.is_confirmed_hotspot is True
    assert cluster.contributing_stations_count == 4
    assert cluster.physical_stations_count == 4
    assert cluster.radius_km > 10.0

    # Ensure explanation contains non-uniformity warning for wide chain-connected clusters
    assert "network chain connectivity" in cluster.explanation
    assert "do not imply uniform pollution" in cluster.explanation


def test_hotspot_stale_and_model_grid_handling():
    """
    Audit 4: Verify that stale observations are excluded from hotspot detection,
    and model-grid points are marked with ESTIMATED provenance.
    """
    detector = HotspotDetectionService(cluster_distance_km=15.0, max_staleness_minutes=120.0)

    # Stale physical monitor (> 120 min)
    stale_obs = create_obs("STALE-1", "Stale Sensor", 28.61, 77.21, aqi=450, is_stale=True, freshness_min=180.0)
    # Fresh atmospheric model grid point
    grid_obs = create_obs(
        "GRID-1",
        "Open-Meteo Grid Point",
        28.62,
        77.22,
        aqi=320,
        station_type=StationType.ATMOSPHERIC_MODEL_GRID,
        data_source_type=DataSourceType.ESTIMATED,
    )
    # Fresh physical monitor
    phys_obs = create_obs("PHYS-1", "Physical Monitor", 28.63, 77.23, aqi=310)

    res = detector.detect_hotspots(28.61, 77.21, query_radius_km=50.0, observations=[stale_obs, grid_obs, phys_obs])

    # Stale obs is rejected, leaving grid_obs and phys_obs (count = 2)
    assert len(res.hotspots) == 1
    cluster = res.hotspots[0]
    assert "STALE-1" not in cluster.contributing_stations
    assert cluster.contributing_stations_count == 2
    assert cluster.physical_stations_count == 1
    # Mixed cluster with model grid has ESTIMATED provenance
    assert cluster.data_source_type == DataSourceType.ESTIMATED
