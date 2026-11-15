"""
AirGuard AI - Air Quality Observation & Status Endpoints
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, status

from app.schemas.pollutant import EnvironmentalObservationInput
from app.schemas.provider import (
    AirQualityHistoryResponse,
    CurrentAirQualityResponse,
    ProviderStatusResponse,
)
from app.services.environmental_service import environmental_service

router = APIRouter()


@router.get(
    "/current",
    response_model=CurrentAirQualityResponse,
    summary="Get Current Air Quality, CPCB AQI, and Risk Assessment",
    description=(
        "Retrieves current air quality for either a specific station_id or GPS coordinates. "
        "Returns normalized pollutant measurements, CPCB IND-AQI calculation, explainable exposure risk, "
        "and data freshness/provenance indicators."
    ),
)
async def get_current_air(
    station_id: Optional[str] = Query(None, description="Station identifier (e.g. OPENAQ-1234, DEMO-DELHI-001)"),
    lat: Optional[float] = Query(None, ge=-90.0, le=90.0, description="User latitude"),
    lon: Optional[float] = Query(None, ge=-180.0, le=180.0, description="User longitude"),
) -> CurrentAirQualityResponse:
    if not station_id and (lat is None or lon is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either 'station_id' or both 'lat' and 'lon' coordinates must be provided.",
        )

    res = await environmental_service.get_current_air_quality(
        station_id=station_id, latitude=lat, longitude=lon
    )
    if not res:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Environmental observation not available for the requested location or station.",
        )
    return res


@router.get(
    "/history",
    response_model=AirQualityHistoryResponse,
    summary="Get Historical Air Quality Observations for a Station",
    description="Returns chronological time series of normalized observations up to the requested hours.",
)
async def get_air_history(
    station_id: str = Query(..., description="Station identifier"),
    hours: int = Query(24, ge=1, le=168, description="Number of historical hours to retrieve"),
) -> AirQualityHistoryResponse:
    observations = await environmental_service.get_air_history(station_id, hours)
    station = await environmental_service.get_station_by_id(station_id)

    return AirQualityHistoryResponse(
        station_id=station_id,
        station_name=station.station_name if station else station_id,
        provider=station.provider if station else "Environmental Provider",
        data_source_type=station.data_source_type if station else "HISTORICAL",
        count=len(observations),
        observations=observations,
    )


@router.get(
    "/providers/status",
    response_model=ProviderStatusResponse,
    summary="Get Health and Connectivity Status of All Configured Providers",
    description=(
        "Reports live status (ONLINE, DEGRADED, UNAUTHENTICATED, OFFLINE), authentication, "
        "latency, supported pollutants, and legal attribution for each data provider."
    ),
)
async def get_providers_status() -> ProviderStatusResponse:
    return await environmental_service.get_providers_status()
