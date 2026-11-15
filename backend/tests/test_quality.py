"""
AirGuard AI - Unit Tests for Data Quality Engine
"""
from datetime import datetime, timezone, timedelta
import pytest
from app.schemas.pollutant import PollutantType
from app.services.quality import (
    convert_and_validate_pollutant,
    check_observation_staleness,
    normalize_unit_string,
)


def test_unit_normalization_strings():
    assert normalize_unit_string("\u00b5g/m\u00b3") == "ug/m3"
    assert normalize_unit_string("\u03bcg/m3") == "ug/m3"
    assert normalize_unit_string("micrograms/m3") == "ug/m3"
    assert normalize_unit_string("ppm") == "ppm"
    assert normalize_unit_string("PPB") == "ppb"


def test_negative_values_rejected():
    val, err = convert_and_validate_pollutant(PollutantType.PM2_5, -15.0, "µg/m³")
    assert val is None
    assert "Negative reading" in err


def test_outlier_values_rejected():
    # PM2.5 above 2000 is rejected as sensor malfunction
    val, err = convert_and_validate_pollutant(PollutantType.PM2_5, 3500.0, "µg/m³")
    assert val is None
    assert "exceeds plausible physical limit" in err


def test_gas_unit_conversion_no2():
    # NO2: 50 ppb at STP = 50 * 1.88 = 94.0 µg/m³
    val, err = convert_and_validate_pollutant(PollutantType.NO2, 50.0, "ppb")
    assert err is None
    assert val == 94.0


def test_gas_unit_conversion_so2():
    # SO2: 20 ppb = 20 * 2.62 = 52.4 µg/m³
    val, err = convert_and_validate_pollutant(PollutantType.SO2, 20.0, "ppb")
    assert err is None
    assert val == 52.4


def test_gas_unit_conversion_co():
    # CO target is mg/m³
    # 2 ppm CO = 2 * 1.145 = 2.29 mg/m³
    val, err = convert_and_validate_pollutant(PollutantType.CO, 2.0, "ppm")
    assert err is None
    assert val == 2.29

    # 3500 µg/m³ CO = 3.5 mg/m³
    val_ug, err_ug = convert_and_validate_pollutant(PollutantType.CO, 3500.0, "µg/m³")
    assert err_ug is None
    assert val_ug == 3.5


def test_staleness_detection():
    now = datetime.now(timezone.utc)
    fresh_time = now - timedelta(minutes=45)
    is_stale, age = check_observation_staleness(fresh_time)
    assert is_stale is False
    assert 40 <= age <= 50

    stale_time = now - timedelta(minutes=150)
    is_stale_old, age_old = check_observation_staleness(stale_time)
    assert is_stale_old is True
    assert 145 <= age_old <= 155
