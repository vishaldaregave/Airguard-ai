"""
AirGuard AI - AQI Calculation & Station Endpoints
"""
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.aqi import AQICalculationResult
from app.schemas.risk import EnvironmentalRiskScore
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.risk_scoring import calculate_exposure_risk

router = APIRouter()


class AssessmentResponse(BaseModel):
    aqi_result: AQICalculationResult = Field(..., description="CPCB AQI evaluation")
    risk_assessment: EnvironmentalRiskScore = Field(..., description="Explainable environmental risk evaluation")


@router.post(
    "/calculate",
    response_model=AssessmentResponse,
    summary="Calculate Deterministic CPCB AQI & Explainable Exposure Risk",
    description=(
        "Performs pure deterministic CPCB calculation with breakpoint interpolation. "
        "Evaluates minimum 3-pollutant criteria with particulate mandate. "
        "Computes explainable exposure risk without hallucinations or medical claims."
    ),
)
async def calculate_aqi_and_risk(observation: EnvironmentalObservationInput) -> AssessmentResponse:
    try:
        aqi_result = calculate_cpcb_aqi(observation)
        risk_result = calculate_exposure_risk(aqi_result, observation)
        return AssessmentResponse(
            aqi_result=aqi_result,
            risk_assessment=risk_result,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deterministic calculation engine error: {str(e)}",
        )


@router.get(
    "/demo-fixtures",
    response_model=List[EnvironmentalObservationInput],
    summary="Get Clearly Labeled Demo Fixtures for UI Development",
    description=(
        "Returns synthetic fixture observations explicitly flagged with data_source_type: DEMO_FIXTURE. "
        "Strictly for UI development and previewing categories (Good, Moderate, Very Poor, Severe)."
    ),
)
async def get_demo_fixtures() -> List[EnvironmentalObservationInput]:
    now = datetime.now(timezone.utc)
    return [
        EnvironmentalObservationInput(
            station_id="DEMO-DELHI-001",
            station_name="Anand Vihar, New Delhi [DEMO FIXTURE]",
            location=LocationCoordinate(
                latitude=28.6508,
                longitude=77.3152,
                city="Delhi",
                state="Delhi",
                country="India",
            ),
            timestamp=now,
            provider="DPCC Demo Sensor Feed",
            data_source_type=DataSourceType.DEMO_FIXTURE,
            pm2_5=185.0,  # Very Poor
            pm10=310.0,   # Poor
            no2=95.0,     # Moderate
            so2=22.0,     # Good
            co=3.2,       # Moderate
            o3=45.0,      # Good
            nh3=85.0,     # Good
            temperature_celsius=19.5,
            relative_humidity_pct=82.0,
            wind_speed_kmh=4.2,
        ),
        EnvironmentalObservationInput(
            station_id="DEMO-MUMBAI-002",
            station_name="BKC, Bandra Kurla Complex [DEMO FIXTURE]",
            location=LocationCoordinate(
                latitude=19.0657,
                longitude=72.8687,
                city="Mumbai",
                state="Maharashtra",
                country="India",
            ),
            timestamp=now,
            provider="MPCB Demo Sensor Feed",
            data_source_type=DataSourceType.DEMO_FIXTURE,
            pm2_5=68.0,   # Moderate
            pm10=115.0,   # Moderate
            no2=45.0,     # Satisfactory
            so2=14.0,     # Good
            co=1.4,       # Satisfactory
            o3=38.0,      # Good
            temperature_celsius=29.0,
            relative_humidity_pct=70.0,
            wind_speed_kmh=12.5,
        ),
        EnvironmentalObservationInput(
            station_id="DEMO-BLR-003",
            station_name="Silk Board, Bengaluru [DEMO FIXTURE]",
            location=LocationCoordinate(
                latitude=12.9177,
                longitude=77.6238,
                city="Bengaluru",
                state="Karnataka",
                country="India",
            ),
            timestamp=now,
            provider="KSPCB Demo Sensor Feed",
            data_source_type=DataSourceType.DEMO_FIXTURE,
            pm2_5=24.0,   # Good
            pm10=42.0,    # Good
            no2=28.0,     # Good
            so2=8.0,      # Good
            co=0.8,       # Good
            o3=30.0,      # Good
            temperature_celsius=24.0,
            relative_humidity_pct=58.0,
            wind_speed_kmh=15.0,
        ),
        EnvironmentalObservationInput(
            station_id="DEMO-KOLKATA-004",
            station_name="Victoria Memorial, Kolkata [DEMO FIXTURE]",
            location=LocationCoordinate(
                latitude=22.5448,
                longitude=88.3426,
                city="Kolkata",
                state="West Bengal",
                country="India",
            ),
            timestamp=now,
            provider="WBPCB Demo Sensor Feed",
            data_source_type=DataSourceType.DEMO_FIXTURE,
            pm2_5=280.0,  # Severe
            pm10=440.0,   # Severe
            no2=190.0,    # Poor
            so2=48.0,     # Satisfactory
            co=12.5,      # Poor
            o3=65.0,      # Satisfactory
            temperature_celsius=21.0,
            relative_humidity_pct=88.0,
            wind_speed_kmh=3.0,
        ),
    ]
