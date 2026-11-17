"""
AirGuard AI - Exposure Simulation API Endpoints
Serves activity profiles, single-scenario exposure simulations, comparative scenarios,
and explainable physical ventilation insights.
"""
from typing import List
from fastapi import APIRouter, HTTPException, status

from app.schemas.exposure import (
    ActivityProfile,
    CompareExposureRequest,
    ExposureComparisonResponse,
    ExposureExplanationRequest,
    ExposureExplanationResponse,
    ExposureSimulationResponse,
    SimulateExposureRequest,
)
from app.services.exposure_service import exposure_service

router = APIRouter()


@router.get(
    "/activity-profiles",
    response_model=List[ActivityProfile],
    summary="Get Supported Physical Activity Profiles",
    description=(
        "Returns documented adult physical activity ventilation rates (m³/h) and MET equivalents "
        "derived from the US EPA Exposure Factors Handbook (2011)."
    ),
)
async def get_activity_profiles() -> List[ActivityProfile]:
    return exposure_service.get_activity_profiles()


@router.post(
    "/simulate",
    response_model=ExposureSimulationResponse,
    summary="Simulate Cumulative Pollutant Exposure",
    description=(
        "Calculates cumulative concentration-time exposure (µg·h/m³) and estimated gross inhaled mass (µg) "
        "based on ambient monitoring/model telemetry, physical activity ventilation rates, and duration (15 to 480 mins)."
    ),
)
async def simulate_exposure(
    request: SimulateExposureRequest,
) -> ExposureSimulationResponse:
    if request.duration_minutes < 15 or request.duration_minutes > 480:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Exposure duration must be between 15 minutes and 480 minutes (8 hours).",
        )

    try:
        return await exposure_service.simulate_exposure(request)
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Exposure simulation failed: {str(e)}",
        )


@router.post(
    "/compare",
    response_model=ExposureComparisonResponse,
    summary="Compare Two Exposure Scenarios",
    description=(
        "Computes a physical delta comparison between Scenario A and Scenario B (different activities, "
        "durations, locations, or forecast windows). Transparently reports mass and ventilation differences "
        "without making clinical claims."
    ),
)
async def compare_exposure_scenarios(
    request: CompareExposureRequest,
) -> ExposureComparisonResponse:
    try:
        return await exposure_service.compare_scenarios(request)
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(ve),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Scenario comparison failed: {str(e)}",
        )


@router.post(
    "/explain",
    response_model=ExposureExplanationResponse,
    summary="Explain Exposure Simulation Results",
    description=(
        "Produces an explainable physical narrative clarifying duration vs exertion trade-offs, "
        "inhalation volume metrics, and actionable protective suggestions."
    ),
)
async def explain_exposure(
    request: ExposureExplanationRequest,
) -> ExposureExplanationResponse:
    try:
        return await exposure_service.explain_exposure(request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Exposure explanation failed: {str(e)}",
        )
