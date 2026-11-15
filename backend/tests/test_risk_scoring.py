"""
AirGuard AI - Unit Tests for Explainable Exposure Risk Engine
"""
from datetime import datetime, timezone
import pytest

from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.risk_scoring import calculate_exposure_risk
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.risk import ExposureRiskLevel


def test_clean_air_exposure_risk():
    """Good AQI yields low risk score and safe activity recommendations."""
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=12.97, longitude=77.59, city="Bengaluru"),
        timestamp=datetime.now(timezone.utc),
        provider="KSPCB",
        data_source_type=DataSourceType.LIVE,
        pm2_5=15.0,
        pm10=30.0,
        no2=18.0,
        wind_speed_kmh=14.0,
        relative_humidity_pct=50.0,
    )
    aqi_res = calculate_cpcb_aqi(obs)
    risk_res = calculate_exposure_risk(aqi_res, obs)

    assert risk_res.risk_score <= 25
    assert risk_res.risk_level == ExposureRiskLevel.LOW
    assert len(risk_res.breakdown) >= 1
    # Check activity guidance
    running_rec = next(r for r in risk_res.activity_recommendations if "Running" in r.activity_type)
    assert running_rec.feasibility == "SAFE"


def test_multi_pollutant_compounding():
    """Simultaneous high PM2.5 and NO2 triggers synergistic exposure compounding."""
    obs = EnvironmentalObservationInput(
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="DPCC",
        data_source_type=DataSourceType.LIVE,
        pm2_5=180.0,  # Very Poor
        pm10=290.0,   # Poor
        no2=190.0,    # Poor (secondary elevated pollutant)
        wind_speed_kmh=2.0,  # Stagnant
        relative_humidity_pct=85.0,  # High moisture trapping
    )
    aqi_res = calculate_cpcb_aqi(obs)
    risk_res = calculate_exposure_risk(aqi_res, obs)

    # Score should be high or hazardous
    assert risk_res.risk_score >= 70
    assert risk_res.risk_level in [ExposureRiskLevel.HIGH, ExposureRiskLevel.VERY_HIGH, ExposureRiskLevel.HAZARDOUS]
    
    # Check that multi-pollutant and stagnation are in breakdown
    factor_names = [f.factor_name for f in risk_res.breakdown]
    assert any("Multi-Pollutant" in name for name in factor_names)
    assert any("Stagnation" in name for name in factor_names)

    # Outdoor exercise must be avoided
    running_rec = next(r for r in risk_res.activity_recommendations if "Running" in r.activity_type)
    assert running_rec.feasibility == "AVOID"

    # Mandatory disclaimer present
    assert "medical diagnosis" in risk_res.disclaimer.lower()
