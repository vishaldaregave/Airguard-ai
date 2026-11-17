"""
AirGuard AI - Location Intelligence Endpoints
"""
from typing import Optional
import httpx
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


@router.get(
    "/detect-ip",
    summary="Detect Client Location via Network IP",
    description="Resolves client approximate geographic coordinates and city name using IP intelligence without requiring hardware GPS.",
)
async def detect_ip_location():
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get("http://ip-api.com/json")
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == "success":
                    return {
                        "status": "success",
                        "latitude": float(data.get("lat", 18.5204)),
                        "longitude": float(data.get("lon", 73.8567)),
                        "city": data.get("city", "Pune"),
                        "state": data.get("regionName", "Maharashtra"),
                        "country": data.get("country", "India"),
                        "countryCode": data.get("countryCode", "IN"),
                    }
    except Exception:
        pass

    # Secondary fallback
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get("https://ipapi.co/json/")
            if resp.status_code == 200:
                data = resp.json()
                return {
                    "status": "success",
                    "latitude": float(data.get("latitude", 18.5204)),
                    "longitude": float(data.get("longitude", 73.8567)),
                    "city": data.get("city", "Pune"),
                    "state": data.get("region", "Maharashtra"),
                    "country": data.get("country_name", "India"),
                    "countryCode": data.get("country_code", "IN"),
                }
    except Exception:
        pass

    return {
        "status": "fallback",
        "latitude": 18.5204,
        "longitude": 73.8567,
        "city": "Pune",
        "state": "Maharashtra",
        "country": "India",
        "countryCode": "IN",
    }
