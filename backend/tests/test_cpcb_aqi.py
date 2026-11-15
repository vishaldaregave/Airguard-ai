"""
AirGuard AI - Unit Tests for Deterministic CPCB AQI Calculation Engine
Validates mathematical correctness against official CPCB India breakpoints.
"""
from datetime import datetime, timezone, timedelta
import pytest

from app.engine.cpcb_aqi import (
    calculate_cpcb_aqi,
    calculate_sub_index,
    get_aqi_category,
)
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
    PollutantType,
)
from app.schemas.aqi import AQICategory, CalculationStatus


def test_sub_index_pm25_breakpoints():
    """Verify PM2.5 sub-index interpolation at exact breakpoints."""
    # Good: 0 - 30 -> 0 - 50
    res_0 = calculate_sub_index(PollutantType.PM2_5, 0.0)
    assert res_0.sub_index == 0
    assert res_0.category == AQICategory.GOOD

    res_30 = calculate_sub_index(PollutantType.PM2_5, 30.0)
    assert res_30.sub_index == 50
    assert res_30.category == AQICategory.GOOD

    # Midpoint of Satisfactory: (31 - 60 -> 51 - 100)
    # At 45 ug/m3: 51 + ((100 - 51) / (60 - 31)) * (45 - 31) = 51 + (49/29)*14 = 51 + 23.65 = 75
    res_45 = calculate_sub_index(PollutantType.PM2_5, 45.0)
    assert res_45.sub_index in [74, 75]
    assert res_45.category == AQICategory.SATISFACTORY

    # Severe: > 250 -> 401 - 500
    res_300 = calculate_sub_index(PollutantType.PM2_5, 300.0)
    assert res_300.sub_index >= 401
    assert res_300.category == AQICategory.SEVERE

    # Extreme value capping at 500
    res_excess = calculate_sub_index(PollutantType.PM2_5, 999.0)
    assert res_excess.sub_index == 500


def test_sub_index_pm10_breakpoints():
    """Verify PM10 sub-index calculation."""
    res = calculate_sub_index(PollutantType.PM10, 50.0)
    assert res.sub_index == 50
    assert res.category == AQICategory.GOOD

    res_mod = calculate_sub_index(PollutantType.PM10, 150.0)
    # 101-250 -> 101-200. At 150: 101 + ((200 - 101)/(250 - 101))*(150 - 101) = 101 + (99/149)*49 = 134
    assert res_mod.sub_index == 134
    assert res_mod.category == AQICategory.MODERATE


def test_sub_index_gases():
    """Verify SO2, NO2, CO, O3, NH3 calculations."""
    res_co = calculate_sub_index(PollutantType.CO, 1.0)
    assert res_co.sub_index == 50

    res_no2 = calculate_sub_index(PollutantType.NO2, 40.0)
    assert res_no2.sub_index == 50

    res_so2 = calculate_sub_index(PollutantType.SO2, 40.0)
    assert res_so2.sub_index == 50

    res_nh3 = calculate_sub_index(PollutantType.NH3, 200.0)
    assert res_nh3.sub_index == 50


def test_cpcb_rule_insufficient_pollutants_under_three():
    """CPCB rule: AQI cannot be calculated with fewer than 3 pollutants."""
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Test Agency",
        data_source_type=DataSourceType.LIVE,
        pm2_5=85.0,
        pm10=180.0,
        # Only 2 pollutants
    )
    res = calculate_cpcb_aqi(obs)
    assert res.status == CalculationStatus.INSUFFICIENT_POLLUTANTS
    assert res.overall_aqi is None
    assert res.monitored_pollutant_count == 2
    assert "at least 3 monitored pollutants" in res.status_message


def test_cpcb_rule_missing_particulate_matter():
    """CPCB rule: AQI cannot be calculated if neither PM2.5 nor PM10 is monitored."""
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Test Agency",
        data_source_type=DataSourceType.LIVE,
        # 3 pollutants, but none are PM2.5 or PM10
        no2=60.0,
        so2=35.0,
        co=1.5,
    )
    res = calculate_cpcb_aqi(obs)
    assert res.status == CalculationStatus.INSUFFICIENT_POLLUTANTS
    assert res.overall_aqi is None
    assert res.has_particulate_matter is False
    assert "particulate matter" in res.status_message


def test_valid_cpcb_aqi_calculation():
    """Valid observation meeting CPCB criteria (3+ pollutants including PM)."""
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Central Pollution Control Board",
        data_source_type=DataSourceType.LIVE,
        pm2_5=110.0,  # Poor (~260-270)
        pm10=150.0,   # Moderate (~134)
        no2=45.0,     # Satisfactory (~57)
    )
    res = calculate_cpcb_aqi(obs)
    assert res.status == CalculationStatus.VALID
    assert res.overall_aqi is not None
    assert res.overall_aqi >= 201 and res.overall_aqi <= 300
    assert res.category == AQICategory.POOR
    assert res.prominent_pollutant == "PM2.5"
    assert res.monitored_pollutant_count == 3
    assert res.has_particulate_matter is True
    assert res.health_advisory is not None


def test_stale_data_detection():
    """Stale data older than 2 hours is flagged with STALE_DATA status."""
    stale_time = datetime.now(timezone.utc) - timedelta(hours=3)
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=stale_time,
        provider="Old Feed",
        data_source_type=DataSourceType.LIVE,
        pm2_5=40.0,
        pm10=70.0,
        no2=30.0,
    )
    res = calculate_cpcb_aqi(obs)
    assert res.is_stale is True
    assert res.status == CalculationStatus.STALE_DATA
    # Calculation is still deterministically correct
    assert res.overall_aqi is not None
