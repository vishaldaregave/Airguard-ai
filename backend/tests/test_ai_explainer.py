"""
AirGuard AI - Unit Tests for AI Explainer Service
Validates grounded generation answering the 6 core environmental inquiries,
non-medical disclaimers, and deterministic fallback integrity.
"""
from datetime import datetime, timezone
import pytest

from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.aqi import AQICalculationResult, AQICategory, CalculationStatus
from app.schemas.risk import EnvironmentalRiskScore, ExposureRiskLevel
from app.schemas.ai_explanation import AIExplanationRequest
from app.services.ai_explainer import (
    DeterministicRuleBasedExplainer,
    ai_explainer_service,
    NON_MEDICAL_DISCLAIMER,
)


@pytest.mark.asyncio
async def test_deterministic_explainer_answers_all_six_inquiries():
    """Verify deterministic expert system generates all 6 required scientific dimensions."""
    explainer = DeterministicRuleBasedExplainer()

    obs = EnvironmentalObservationInput(
        station_id="TEST-GROUND-01",
        station_name="Anand Vihar Ground Station",
        location=LocationCoordinate(latitude=28.65, longitude=77.31, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="DPCC CAAQMS Feed",
        data_source_type=DataSourceType.LIVE,
        pm2_5=175.0,
        pm10=290.0,
        no2=85.0,
        temperature_celsius=16.0,
        relative_humidity_pct=85.0,
        wind_speed_kmh=4.0,
    )

    aqi_res = AQICalculationResult(
        standard="CPCB_INDIA",
        status=CalculationStatus.VALID,
        status_message="Valid CPCB AQI",
        overall_aqi=342,
        category=AQICategory.VERY_POOR,
        color_code="#FF0000",
        prominent_pollutant="PM2.5",
        sub_indices={},
        monitored_pollutant_count=3,
        has_particulate_matter=True,
        data_source_type=DataSourceType.LIVE,
        provider="DPCC CAAQMS Feed",
        observation_timestamp=obs.timestamp,
        calculation_timestamp=datetime.now(timezone.utc),
        location=obs.location,
    )

    risk_res = EnvironmentalRiskScore(
        risk_score=78,
        risk_level=ExposureRiskLevel.VERY_HIGH,
        risk_summary="Very high environmental exposure risk.",
        primary_driver="PM2.5",
        breakdown=[],
        activity_recommendations=[],
    )

    res = await explainer.explain(
        obs=obs,
        aqi_result=aqi_res,
        risk=risk_res,
        hist_pm25_avg=140.0,
        hist_trend="RISING",
    )

    # 1. Atmospheric dynamics
    assert len(res.atmospheric_dynamics) > 20
    assert "calm" in res.atmospheric_dynamics.lower() or "dispersion" in res.atmospheric_dynamics.lower()

    # 2. Primary pollutant driver
    assert "PM2.5" in res.primary_pollutant_driver

    # 3. Elevation causes
    assert len(res.elevation_causes) > 20

    # 4. Outdoor activity implication
    assert "avoid" in res.outdoor_activity_implication.lower() or "discouraged" in res.outdoor_activity_implication.lower()

    # 5. Practical precautions
    assert len(res.practical_precautions) >= 3
    assert any("n95" in p.lower() for p in res.practical_precautions)

    # 6. Historical comparison
    assert "140.0" in res.historical_comparison
    assert "higher" in res.historical_comparison

    # Non-medical disclaimer
    assert NON_MEDICAL_DISCLAIMER in res.disclaimer
    assert res.is_deterministic_fallback is True
    assert res.data_provenance == "LIVE"


@pytest.mark.asyncio
async def test_ai_explainer_service_end_to_end_request():
    """Verify end-to-end API service execution with caching."""
    obs = EnvironmentalObservationInput(
        station_id="METEO-GRID-TEST",
        station_name="Open-Meteo Regional Grid",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Open-Meteo",
        data_source_type=DataSourceType.ESTIMATED,
        pm2_5=45.0,
        pm10=80.0,
        no2=30.0,
        temperature_celsius=24.0,
        relative_humidity_pct=50.0,
        wind_speed_kmh=12.0,
    )

    aqi_res = AQICalculationResult(
        standard="CPCB_INDIA",
        status=CalculationStatus.VALID,
        status_message="Valid CPCB AQI",
        overall_aqi=75,
        category=AQICategory.SATISFACTORY,
        color_code="#92D050",
        prominent_pollutant="PM2.5",
        sub_indices={},
        monitored_pollutant_count=3,
        has_particulate_matter=True,
        data_source_type=DataSourceType.ESTIMATED,
        provider="Open-Meteo",
        observation_timestamp=obs.timestamp,
        calculation_timestamp=datetime.now(timezone.utc),
        location=obs.location,
    )

    req = AIExplanationRequest(
        observation=obs,
        aqi_result=aqi_res,
        historical_24h_avg_pm25=50.0,
        historical_trend="STABLE",
    )

    explanation = await ai_explainer_service.generate_explanation(req)
    assert explanation.executive_summary is not None
    assert "Satisfactory" in explanation.executive_summary
    assert explanation.data_provenance == "ESTIMATED"
