"""
AirGuard AI - Unit Tests for Data Quality Engine
Validates gas unit conversion under Standard Reference Conditions (25 °C, 1013.25 hPa)
and ambient temperature/pressure adjustments, outlier filtering, provider staleness,
future timestamp detection, and coordinate validation.
"""
from datetime import datetime, timezone, timedelta
import pytest
from app.schemas.pollutant import DataSourceType, PollutantType
from app.services.quality import (
    convert_and_validate_pollutant,
    convert_and_validate_with_metadata,
    compute_gas_conversion_factor,
    check_observation_staleness,
    normalize_unit_string,
    validate_station_coordinates,
)


def test_unit_normalization_strings():
    assert normalize_unit_string("µg/m³") == "ug/m3"
    assert normalize_unit_string("μg/m3") == "ug/m3"
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


def test_gas_unit_conversion_all_supported_gases_reference_conditions():
    """Verify all 5 supported gases under CPCB Standard Reference Conditions (25 °C, 1013.25 hPa)."""
    # NO2: 50 ppb * 1.8804 = 94.02 µg/m³
    val_no2, err = convert_and_validate_pollutant(PollutantType.NO2, 50.0, "ppb")
    assert err is None
    assert val_no2 == pytest.approx(94.0, abs=0.2)

    # SO2: 20 ppb * 2.6186 = 52.37 µg/m³
    val_so2, err = convert_and_validate_pollutant(PollutantType.SO2, 20.0, "ppb")
    assert err is None
    assert val_so2 == pytest.approx(52.4, abs=0.2)

    # CO: 2 ppm * 1.1449 = 2.29 mg/m³
    val_co, err = convert_and_validate_pollutant(PollutantType.CO, 2.0, "ppm")
    assert err is None
    assert val_co == pytest.approx(2.29, abs=0.1)

    # O3: 30 ppb * 1.9619 = 58.86 µg/m³
    val_o3, err = convert_and_validate_pollutant(PollutantType.O3, 30.0, "ppb")
    assert err is None
    assert val_o3 == pytest.approx(58.9, abs=0.2)

    # NH3: 100 ppb * 0.6961 = 69.61 µg/m³
    val_nh3, err = convert_and_validate_pollutant(PollutantType.NH3, 100.0, "ppb")
    assert err is None
    assert val_nh3 == pytest.approx(69.6, abs=0.5)


def test_temperature_pressure_aware_gas_conversion():
    """Verify ideal gas law scaling with ambient temperature and atmospheric pressure."""
    # NO2: M = 46.0055 g/mol
    # At 0 °C (273.15 K) and 1013.25 hPa: V_m = (8.31446 * 273.15 * 10) / 1013.25 = 22.414 L/mol
    # Factor = 46.0055 / 22.414 = 2.0525 µg/m³ per ppb (approx 9.1% higher than at 25 °C)
    factor_cold, desc_cold = compute_gas_conversion_factor(
        PollutantType.NO2, "ppb", temperature_celsius=0.0, pressure_hpa=1013.25
    )
    assert round(factor_cold, 2) == 2.05
    assert "Ambient conditions adjusted" in desc_cold

    # At 35 °C (308.15 K) and 1000.0 hPa:
    # V_m = (8.31446 * 308.15 * 10) / 1000.0 = 25.621 L/mol
    # Factor = 46.0055 / 25.621 = 1.7956 µg/m³ per ppb
    factor_hot, _ = compute_gas_conversion_factor(
        PollutantType.NO2, "ppb", temperature_celsius=35.0, pressure_hpa=1000.0
    )
    assert round(factor_hot, 2) == 1.80

    # Validate end-to-end convert_and_validate_pollutant with ambient T & P
    val_ambient, err = convert_and_validate_pollutant(
        PollutantType.NO2, 100.0, "ppb", temperature_celsius=0.0, pressure_hpa=1013.25
    )
    assert err is None
    assert val_ambient == pytest.approx(205.25, abs=0.1)


def test_conversion_metadata_preservation():
    """Verify raw value, raw unit, normalized unit, conversion factor and reference conditions are preserved."""
    val, err, meta = convert_and_validate_with_metadata(
        PollutantType.CO, 3.0, "ppm", temperature_celsius=25.0, pressure_hpa=1013.25
    )
    assert err is None
    assert val is not None
    assert meta["pollutant"] == "CO"
    assert meta["raw_value"] == 3.0
    assert meta["raw_unit"] == "ppm"
    assert meta["normalized_unit"] == "mg/m³"
    assert meta["validation_status"] == "VALID"
    assert "conversion_factor" in meta
    assert "reference_condition" in meta


def test_provider_specific_staleness_thresholds():
    """Different providers have different refresh intervals: Open-Meteo (90m), OpenAQ (120m), CPCB (180m)."""
    now = datetime.now(timezone.utc)

    # 100-minute-old observation:
    # Should be stale for Open-Meteo (threshold 90m)
    stale_meteo, age1 = check_observation_staleness(now - timedelta(minutes=100), provider_name="open_meteo")
    assert stale_meteo is True
    assert 99 <= age1 <= 101

    # But fresh for CPCB / data.gov.in (threshold 180m)
    stale_cpcb, age2 = check_observation_staleness(now - timedelta(minutes=100), provider_name="cpcb_datagov")
    assert stale_cpcb is False

    # And fresh for OpenAQ (threshold 120m)
    stale_openaq, age3 = check_observation_staleness(now - timedelta(minutes=100), provider_name="openaq")
    assert stale_openaq is False


def test_future_timestamp_validation():
    """Future timestamps are valid for FORECAST, but flagged as anomalous for LIVE/ESTIMATED data."""
    now = datetime.now(timezone.utc)
    future_time = now + timedelta(hours=3)

    # For FORECAST: valid
    is_stale_fc, _ = check_observation_staleness(future_time, data_source_type=DataSourceType.FORECAST)
    assert is_stale_fc is False

    # For LIVE: flagged as clock drift anomaly
    is_stale_live, _ = check_observation_staleness(future_time, data_source_type=DataSourceType.LIVE)
    assert is_stale_live is True


def test_coordinate_validation():
    """Validates geographic latitude/longitude boundaries and rejects Null Island."""
    # Valid Delhi coordinates
    valid, err = validate_station_coordinates(28.6139, 77.2090)
    assert valid is True
    assert err is None

    # Null Island (0, 0)
    valid_null, err_null = validate_station_coordinates(0.0, 0.0)
    assert valid_null is False
    assert "Null Island" in err_null

    # Out of latitude bounds
    valid_lat, err_lat = validate_station_coordinates(95.0, 77.2)
    assert valid_lat is False
    assert "Latitude" in err_lat

    # Out of longitude bounds
    valid_lon, err_lon = validate_station_coordinates(28.6, 185.0)
    assert valid_lon is False
    assert "Longitude" in err_lon
