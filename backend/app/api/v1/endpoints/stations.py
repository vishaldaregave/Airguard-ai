"""
AirGuard AI - Monitoring Stations Endpoints
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, status

from app.schemas.provider import MonitoringStationSummary
from app.services.environmental_service import environmental_service

router = APIRouter()


@router.get(
    "/nearby",
    response_model=List[MonitoringStationSummary],
    summary="List Monitoring Stations Discovered Near Coordinates",
    description="Returns verified physical ground stations, model grid points, and demo fixtures sorted by distance.",
)
async def get_nearby_stations(
    lat: float = Query(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees"),
    lon: float = Query(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees"),
    radius_km: Optional[float] = Query(25.0, ge=1.0, le=200.0, description="Search radius in kilometers"),
    include_demo: bool = Query(True, description="Whether to include demonstration fixtures in discovery"),
) -> List[MonitoringStationSummary]:
    try:
        return await environmental_service.get_nearby_stations(lat, lon, radius_km, include_demo)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Station retrieval error: {str(e)}",
        )


@router.get(
    "/{station_id}",
    response_model=MonitoringStationSummary,
    summary="Get Monitoring Station Metadata by ID",
    description="Retrieves station details, provider name, monitored pollutants, and coordinates.",
)
async def get_station_details(station_id: str) -> MonitoringStationSummary:
    station = await environmental_service.get_station_by_id(station_id)
    if not station:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Monitoring station '{station_id}' not found.",
        )
    return station
