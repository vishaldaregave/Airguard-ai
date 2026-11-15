"""
AirGuard AI - Location Intelligence Endpoints
"""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query, status

from app.schemas.provider import LocationNearbyResponse
from app.services.environmental_service import environmental_service

router = APIRouter()


@router.get(
    "/nearby",
    response_model=LocationNearbyResponse,
    summary="Discover Nearby Stations and Coverage for Given Coordinates",
    description=(
        "Processes GPS coordinates, calculates Haversine distances to monitoring stations, "
        "and returns station summaries with data provenance (LIVE, ESTIMATED, or DEMO_FIXTURE)."
    ),
)
async def get_nearby_locations(
    lat: float = Query(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees"),
    lon: float = Query(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees"),
    radius_km: Optional[float] = Query(25.0, ge=1.0, le=200.0, description="Search radius in kilometers"),
) -> LocationNearbyResponse:
    try:
        return await environmental_service.get_location_discovery(lat, lon, radius_km)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Location discovery failed: {str(e)}",
        )
