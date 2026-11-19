"""
AirGuard AI - Location Intelligence Endpoints
"""
from typing import Optional
import ipaddress
import httpx
from fastapi import APIRouter, HTTPException, Query, Request, status

from app.schemas.provider import LocationNearbyResponse
from app.services.environmental_service import environmental_service

router = APIRouter()

DEFAULT_LATITUDE = 18.5204
DEFAULT_LONGITUDE = 73.8567


def _client_ip(request: Request) -> Optional[str]:
    """Returns the caller's public IP when it can be determined."""
    forwarded = request.headers.get("x-forwarded-for")
    candidate = None
    if forwarded:
        candidate = forwarded.split(",")[0].strip()
    elif request.client is not None:
        candidate = request.client.host

    if not candidate:
        return None

    try:
        address = ipaddress.ip_address(candidate)
    except ValueError:
        return None

    if address.is_private or address.is_loopback or address.is_reserved:
        return None
    return str(address)


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
async def detect_ip_location(request: Request):
    client_ip = _client_ip(request)
    ipapi_path = f"https://ipapi.co/{client_ip}/json/" if client_ip else "https://ipapi.co/json/"

    # Primary: HTTPS provider that can resolve the caller's own address.
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(ipapi_path)
            if resp.status_code == 200:
                data = resp.json()
                latitude = data.get("latitude")
                longitude = data.get("longitude")
                if latitude is not None and longitude is not None:
                    return {
                        "status": "success",
                        "latitude": float(latitude),
                        "longitude": float(longitude),
                        "city": data.get("city"),
                        "state": data.get("region"),
                        "country": data.get("country_name"),
                        "countryCode": data.get("country_code"),
                    }
    except Exception:
        pass

    # Secondary provider.
    try:
        lookup = client_ip or ""
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(f"http://ip-api.com/json/{lookup}")
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == "success":
                    return {
                        "status": "success",
                        "latitude": float(data.get("lat")),
                        "longitude": float(data.get("lon")),
                        "city": data.get("city"),
                        "state": data.get("regionName"),
                        "country": data.get("country"),
                        "countryCode": data.get("countryCode"),
                    }
    except Exception:
        pass

    # Do not present a guessed city as the client's location.
    return {
        "status": "fallback",
        "latitude": DEFAULT_LATITUDE,
        "longitude": DEFAULT_LONGITUDE,
        "city": None,
        "state": None,
        "country": None,
        "countryCode": None,
    }
