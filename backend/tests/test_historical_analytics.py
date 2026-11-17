"""
AirGuard AI - Milestone 5.4 Historical Analytics & Environmental Intelligence Tests
Validates linear trend evaluation, data gap detection, missing pollutant integrity,
calendar aggregation with CPCB 16-hour rule, peak episode detection, location comparison,
report generation, and all historical API contracts.
"""
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.history import (
    CalendarDayStatus,
    HistoricalCompareRequest,
    HistoricalExplanationRequest,
    PeriodType,
    TrendDirection,
)
from app.engine.historical_analytics_engine import (
    aggregate_calendar_days,
    calculate_linear_trend,
    compute_diurnal_profile,
    compute_pollutant_statistics,
    compare_historical_locations,
    detect_data_gaps,
    detect_extreme_episodes,
)

client = TestClient(app)


# =========================================================================
# 1. CORE ENGINE & MATHEMATICAL FORMULATION TESTS
# =========================================================================

def test_linear_trend_calculation_increasing_and_decreasing():
    """
    Verify linear regression OLS trend evaluation:
    - Strictly increasing series yields INCREASING, positive slope, R² > 0.8
    - Strictly decreasing series yields DECREASING, negative slope, R² > 0.8
    - Stable series yields STABLE
    - Insufficient data points yields INSUFFICIENT_DATA
    """
    now = datetime.now(timezone.utc)
    timestamps = [now + timedelta(hours=i) for i in range(12)]

    # 1. Increasing trend
    y_inc = [50.0 + i * 10.0 for i in range(12)]
    d_inc, slope_inc, r2_inc, sig_inc = calculate_linear_trend(timestamps, y_inc, min_samples=6)
    assert d_inc == TrendDirection.INCREASING
    assert slope_inc > 0.0
    assert r2_inc >= 0.90
    assert sig_inc is True

    # 2. Decreasing trend
    y_dec = [200.0 - i * 8.0 for i in range(12)]
    d_dec, slope_dec, r2_dec, sig_dec = calculate_linear_trend(timestamps, y_dec, min_samples=6)
    assert d_dec == TrendDirection.DECREASING
    assert slope_dec < 0.0
    assert r2_dec >= 0.90
    assert sig_dec is True

    # 3. Stable trend (flat)
    y_stable = [120.0 for _ in range(12)]
    d_st, slope_st, r2_st, sig_st = calculate_linear_trend(timestamps, y_stable, min_samples=6)
    assert d_st == TrendDirection.STABLE
    assert slope_st == 0.0

    # 4. Insufficient samples
    d_insuf, _, _, _ = calculate_linear_trend(timestamps[:3], y_inc[:3], min_samples=6)
    assert d_insuf == TrendDirection.INSUFFICIENT_DATA


def test_data_gap_detection():
    """
    Verify detection of missing observation telemetry windows:
    - Continuous 1-hour interval yields zero gaps.
    - An artificial jump of 6 hours between reading 4 and 5 yields a 6.0h gap.
    """
    now = datetime.now(timezone.utc)
    
    # Continuous
    ts_cont = [now + timedelta(hours=i) for i in range(10)]
    gaps_cont = detect_data_gaps(ts_cont, expected_interval_hours=1.0, gap_threshold_hours=2.0)
    assert len(gaps_cont) == 0

    # With a 6-hour gap between hour 3 and hour 9
    ts_with_gap = [now + timedelta(hours=i) for i in range(4)] + [now + timedelta(hours=9 + i) for i in range(4)]
    gaps = detect_data_gaps(ts_with_gap, expected_interval_hours=1.0, gap_threshold_hours=2.0)
    assert len(gaps) == 1
    assert gaps[0].duration_hours == 6.0
    assert "Missing observation telemetry window" in gaps[0].reason


def test_pollutant_statistics_missing_values_preserved():
    """
    Descriptive statistics must preserve None/missing readings and never coerce to zero.
    Verify mean, median, min, max, standard deviation, and standard limit exceedance.
    """
    # PM2.5 readings (C_std = 60 µg/m³) with 2 missing readings out of 6 expected
    vals = [40.0, 70.0, 90.0, None, 100.0, None]
    stat = compute_pollutant_statistics("PM2.5", vals, total_expected_samples=6)

    assert stat.pollutant == "PM2.5"
    assert stat.unit == "µg/m³"
    assert stat.valid_samples_count == 4
    # Mean of [40, 70, 90, 100] = 75.0
    assert stat.mean == 75.0
    # Median of [40, 70, 90, 100] = (70 + 90) / 2 = 80.0
    assert stat.median == 80.0
    assert stat.min_value == 40.0
    assert stat.max_value == 100.0
    # Completeness: 4 / 6 * 100 = 66.7%
    assert stat.completeness_pct == pytest.approx(66.7, abs=0.2)
    # Exceedance: 70, 90, 100 exceed 60 µg/m³ -> 3 samples
    assert stat.statutory_standard_exceeded_count == 3


def test_calendar_aggregation_cpcb_16_hour_rule():
    """
    Verify statutory CPCB NAAQS 16-Hour minimum rule for valid daily AQI:
    - Day with 20 hourly samples (>= 16): AVAILABLE and is_cpcb_valid_day = True
    - Day with 10 hourly samples (< 16): INSUFFICIENT_SAMPLES and is_cpcb_valid_day = False
    - Day with 0 samples: UNAVAILABLE and is_cpcb_valid_day = False
    """
    class MockObs:
        def __init__(self, ts, aqi, pm25=80.0):
            self.timestamp = ts
            self.calculated_aqi = aqi
            self.pm2_5 = pm25
            self.pm10 = 150.0
            self.no2 = 40.0
            self.so2 = 20.0
            self.co = 1.5
            self.o3 = 30.0
            self.prominent_pollutant = "PM2.5"
            self.aqi_category = "Poor"

    now = datetime(2026, 11, 15, 0, 0, tzinfo=timezone.utc)
    obs_list = []

    # Day 1 (Nov 15): 20 samples -> VALID
    for h in range(20):
        obs_list.append(MockObs(now + timedelta(hours=h), 220))

    # Day 2 (Nov 16): 10 samples -> INSUFFICIENT
    for h in range(10):
        obs_list.append(MockObs(now + timedelta(days=1, hours=h), 180))

    # Day 3 (Nov 17): 0 samples -> UNAVAILABLE

    start = now
    end = now + timedelta(days=2, hours=23)
    days = aggregate_calendar_days(obs_list, start, end, timezone_offset_hours=0.0)

    assert len(days) == 3
    # Day 1
    assert days[0].date == "2026-11-15"
    assert days[0].sample_count == 20
    assert days[0].is_cpcb_valid_day is True
    assert days[0].status == CalendarDayStatus.AVAILABLE
    assert days[0].representative_aqi == 220
    assert days[0].aqi_category == "Poor"

    # Day 2
    assert days[1].date == "2026-11-16"
    assert days[1].sample_count == 10
    assert days[1].is_cpcb_valid_day is False
    assert days[1].status == CalendarDayStatus.INSUFFICIENT_SAMPLES

    # Day 3
    assert days[2].date == "2026-11-17"
    assert days[2].sample_count == 0
    assert days[2].is_cpcb_valid_day is False
    assert days[2].status == CalendarDayStatus.UNAVAILABLE
    assert days[2].representative_aqi is None


def test_extreme_episode_detection():
    """
    Detects continuous elevated episodes (AQI >= 200 for >= 2 hours)
    and clean episodes (AQI <= 100 for >= 2 hours).
    """
    class MockObs:
        def __init__(self, ts, aqi, temp=22.0, wind=3.5):
            self.timestamp = ts
            self.calculated_aqi = aqi
            self.temperature_celsius = temp
            self.wind_speed_kmh = wind
            self.relative_humidity_pct = 60.0

    now = datetime(2026, 11, 10, 0, 0, tzinfo=timezone.utc)
    obs_list = []

    # 4 hours of elevated episode (AQI 250-320)
    for h in range(4):
        obs_list.append(MockObs(now + timedelta(hours=h), 250 + h * 20))

    # 3 hours of moderate (AQI 150)
    for h in range(4, 7):
        obs_list.append(MockObs(now + timedelta(hours=h), 150))

    # 3 hours of clean air (AQI 70-80)
    for h in range(7, 10):
        obs_list.append(MockObs(now + timedelta(hours=h), 75))

    peaks, cleans = detect_extreme_episodes(obs_list, elevated_threshold_aqi=200, clean_threshold_aqi=100)

    assert len(peaks) == 1
    assert peaks[0].peak_value == 310.0
    assert peaks[0].duration_hours == 4.0

    assert len(cleans) == 1
    assert cleans[0].peak_value == 75.0
    assert cleans[0].duration_hours == 3.0


def test_location_comparison_provenance_and_deltas():
    """
    Verifies comparative analytics between Location A and Location B:
    - Discloses physical station vs model grid differences.
    - Computes delta AQI and delta pollutants.
    """
    class MockLoc:
        def __init__(self, name, is_phys, cov, mean_aqi, pol_means):
            self.station_name = name
            self.is_physical_station = is_phys
            self.data_coverage_pct = cov
            self.mean_aqi = mean_aqi
            self.pollutant_means = pol_means

    loc_a = MockLoc("Connaught Place (Physical)", True, 95.0, 220.0, {"PM2.5": 110.0, "PM10": 190.0})
    loc_b = MockLoc("Open-Meteo Regional Grid", False, 98.0, 180.0, {"PM2.5": 85.0, "PM10": 140.0})

    is_compat, compat_msg, d_aqi, p_deltas, summary = compare_historical_locations(
        loc_a, loc_b, label_a="Ground Station", label_b="Model Grid"
    )

    assert is_compat is True
    assert "Provenance Caveat" in compat_msg
    assert "chemical transport model grid" in compat_msg
    # Delta AQI = Location B (180) - Location A (220) = -40.0
    assert d_aqi == -40.0
    # Delta PM2.5 = 85.0 - 110.0 = -25.0
    assert p_deltas["PM2.5"] == -25.0
    assert "Comparative Environmental Assessment" in summary


# =========================================================================
# 2. BACKEND API ENDPOINT INTEGRATION TESTS
# =========================================================================

def test_api_history_summary_endpoint():
    """GET /api/v1/history/summary returns comprehensive statistics."""
    res = client.get("/api/v1/history/summary?station_id=METEO-GRID-28.61-77.21&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert data["station_id"] == "METEO-GRID-28.61-77.21"
    assert data["period"] == "7d"
    assert data["total_records"] > 0
    assert data["aqi_mean"] is not None
    assert "PM2.5" in data["pollutant_summaries"]
    assert "Methodology" in data["methodology_notes"]
    assert "disclaimer" in data


def test_api_history_trends_endpoint():
    """GET /api/v1/history/trends returns slope, R², time points, and diurnal profile."""
    res = client.get("/api/v1/history/trends?station_id=METEO-GRID-28.61-77.21&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert "trend_direction" in data
    assert "slope_aqi_per_day" in data
    assert "r_squared" in data
    assert len(data["time_points"]) > 0
    assert len(data["diurnal_profile"]) == 24
    assert "0" in data["diurnal_profile"]
    assert "12" in data["diurnal_profile"]


def test_api_history_pollutants_endpoint():
    """GET /api/v1/history/pollutants returns criteria pollutant trends."""
    res = client.get("/api/v1/history/pollutants?station_id=METEO-GRID-28.61-77.21&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert "pollutants" in data
    pols = data["pollutants"]
    assert "PM2.5" in pols
    assert "PM10" in pols
    assert "NO2" in pols
    assert pols["PM2.5"]["cpcb_standard_limit"] == 60.0
    assert len(pols["PM2.5"]["series"]) > 0


def test_api_history_extremes_endpoint():
    """GET /api/v1/history/extremes detects peak episodes and cleanest windows."""
    res = client.get("/api/v1/history/extremes?station_id=METEO-GRID-28.61-77.21&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert "peak_episodes" in data
    assert "cleanest_periods" in data
    assert "observations_insights" in data


def test_api_history_calendar_endpoint():
    """GET /api/v1/history/calendar returns daily items enforcing CPCB 16-hr rule."""
    res = client.get("/api/v1/history/calendar?station_id=METEO-GRID-28.61-77.21&period=30d")
    assert res.status_code == 200
    data = res.json()
    assert "days" in data
    assert len(data["days"]) > 0
    assert "cpcb_16_hour_rule_note" in data
    # Check first day schema
    day0 = data["days"][0]
    assert "date" in day0
    assert "status" in day0
    assert "is_cpcb_valid_day" in day0
    assert "pollutant_means" in day0


def test_api_history_compare_endpoint():
    """POST /api/v1/history/compare compares two stations."""
    payload = {
        "station_id_a": "METEO-GRID-28.61-77.21",
        "station_id_b": "METEO-GRID-28.61-77.21",
        "period": "7d",
        "label_a": "North Hub",
        "label_b": "South Hub",
    }
    res = client.post("/api/v1/history/compare", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "location_a" in data
    assert "location_b" in data
    assert "compatibility_assessment" in data
    assert "comparative_summary" in data


def test_api_history_coverage_endpoint():
    """GET /api/v1/history/coverage audits data completeness and regularity score."""
    res = client.get("/api/v1/history/coverage?station_id=METEO-GRID-28.61-77.21&period=30d")
    assert res.status_code == 200
    data = res.json()
    assert "expected_samples" in data
    assert "actual_samples" in data
    assert "coverage_pct" in data
    assert "temporal_regularity_score" in data
    assert "gap_intervals" in data


def test_api_history_report_endpoint():
    """GET /api/v1/history/report generates publication-ready Markdown report."""
    res = client.get("/api/v1/history/report?station_id=METEO-GRID-28.61-77.21&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert "title" in data
    assert "executive_summary" in data
    assert "markdown_content" in data
    assert "# AIRGUARD AI" in data["markdown_content"]
    assert "Criteria Pollutant Concentration Summary" in data["markdown_content"]


def test_api_history_explain_endpoint():
    """POST /api/v1/history/explain returns structured non-clinical evidence narrative."""
    summary_data = client.get("/api/v1/history/summary?station_id=METEO-GRID-28.61-77.21&period=7d").json()
    trends_data = client.get("/api/v1/history/trends?station_id=METEO-GRID-28.61-77.21&period=7d").json()

    payload = {
        "summary": summary_data,
        "trends": trends_data,
        "user_query": "What drove peak pollution this week?",
    }
    res = client.post("/api/v1/history/explain", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "narrative" in data
    assert len(data["key_insights"]) >= 1
    assert "Non-Causal Notice" in str(data["data_limitations"])
    assert "Scientific Environmental Advisory" in data["disclaimer"]


def test_sparse_and_empty_history_graceful_handling():
    """
    Querying an unknown station with zero stored observations returns honest
    coverage_pct=0.0 and INSUFFICIENT_DATA without crashing or fabricating fake points.
    """
    res = client.get("/api/v1/history/summary?station_id=UNKNOWN-STATION-999&period=7d")
    assert res.status_code == 200
    data = res.json()
    assert data["total_records"] == 0
    assert data["data_coverage_pct"] == 0.0
    assert data["aqi_mean"] is None
    assert data["overall_trend"] == "INSUFFICIENT_DATA"
    assert "No historical archive observations recorded" in data["methodology_notes"]
