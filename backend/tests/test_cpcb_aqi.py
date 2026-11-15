"""
AirGuard AI - Unit Tests for Deterministic CPCB AQI Calculation Engine
Validates mathematical correctness against official CPCB India breakpoints and reference examples.
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
    assert res_0.averaging_period_hours == 24

    res_30 = calculate_sub_index(PollutantType.PM2_5, 30.0)
    assert res_30.sub_index == 50
    assert res_30.category == AQICategory.GOOD

    # Official CPCB Example A:
    # At 45 µg/m³ PM2.5: (100 - 50)/(60 - 30) * (45 - 30) + 50 = (50/30)*15 + 50 = 25 + 50 = 75
    res_45 = calculate_sub_index(PollutantType.PM2_5, 45.0)
    assert res_45.sub_index == 75
    assert res_45.category == AQICategory.SATISFACTORY

    # Official CPCB Example B:
    # At 150 µg/m³ PM2.5: (400 - 300)/(250 - 120) * (150 - 120) + 300 = (100/130)*30 + 300 = 23.08 + 300 = 323
    res_150 = calculate_sub_index(PollutantType.PM2_5, 150.0)
    assert res_150.sub_index == 323
    assert res_150.category == AQICategory.VERY_POOR

    # Severe: > 250 -> 400 - 500
    res_300 = calculate_sub_index(PollutantType.PM2_5, 300.0)
    assert res_300.sub_index == 450
    assert res_300.category == AQICategory.SEVERE

    # Extreme value capping at 500
    res_excess = calculate_sub_index(PollutantType.PM2_5, 999.0)
    assert res_excess.sub_index == 500


def test_sub_index_pm10_breakpoints():
    """Verify PM10 sub-index calculation."""
    res = calculate_sub_index(PollutantType.PM10, 50.0)
    assert res.sub_index == 50
    assert res.category == AQICategory.GOOD
    assert res.averaging_period_hours == 24

    # Moderate range: 100 - 250 -> 100 - 200
    # At 150: 100 + ((200 - 100) / (250 - 100)) * (150 - 100) = 100 + (100/150)*50 = 100 + 33.33 = 133
    res_mod = calculate_sub_index(PollutantType.PM10, 150.0)
    assert res_mod.sub_index == 133
    assert res_mod.category == AQICategory.MODERATE


def test_sub_index_gases():
    """Verify SO2, NO2, CO, O3, NH3 calculations and averaging periods."""
    res_co = calculate_sub_index(PollutantType.CO, 1.0)
    assert res_co.sub_index == 50
    assert res_co.averaging_period_hours == 8

    res_no2 = calculate_sub_index(PollutantType.NO2, 40.0)
    assert res_no2.sub_index == 50
    assert res_no2.averaging_period_hours == 24

    res_so2 = calculate_sub_index(PollutantType.SO2, 40.0)
    assert res_so2.sub_index == 50
    assert res_so2.averaging_period_hours == 24

    res_o3 = calculate_sub_index(PollutantType.O3, 50.0)
    assert res_o3.sub_index == 50
    assert res_o3.averaging_period_hours == 8

    res_nh3 = calculate_sub_index(PollutantType.NH3, 200.0)
    assert res_nh3.sub_index == 50
    assert res_nh3.averaging_period_hours == 24


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
        pm2_5=110.0,  # Poor (90-120 -> 200-300: 200 + (100/30)*20 = 267)
        pm10=150.0,   # Moderate (~133)
        no2=45.0,     # Satisfactory (~56)
    )
    res = calculate_cpcb_aqi(obs)
    assert res.status == CalculationStatus.VALID
    assert res.overall_aqi == 267
    assert res.category == AQICategory.POOR
    assert res.prominent_pollutant == "PM2.5"
    assert res.monitored_pollutant_count == 3
    assert res.has_particulate_matter is True
    assert res.health_advisory is not None


def test_official_cpcb_overall_aqi_and_dominant_pollutant():
    """Official CPCB case: Ip(PM2.5) = 75, Ip(SO2) = 63, Ip(NO2) = 38 -> AQI = 75, Dominant = PM2.5."""
    # PM2.5 = 45 -> sub_index 75
    # SO2 = 50 -> (100-50)/(80-40)*(50-40)+50 = (50/40)*10+50 = 12.5+50 = 63
    # NO2 = 30 -> (50/40)*30 = 38
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Central Pollution Control Board",
        data_source_type=DataSourceType.LIVE,
        pm2_5=45.0,
        so2=50.0,
        no2=30.0,
    )
    res = calculate_cpcb_aqi(obs)
    assert res.status == CalculationStatus.VALID
    assert res.sub_indices["PM2.5"].sub_index == 75
    assert res.sub_indices["SO2"].sub_index == 63
    assert res.sub_indices["NO2"].sub_index == 38
    assert res.overall_aqi == 75
    assert res.category == AQICategory.SATISFACTORY
    assert res.prominent_pollutant == "PM2.5"


def test_stale_data_detection():
    """Stale data older than threshold is flagged with STALE_DATA status."""
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
