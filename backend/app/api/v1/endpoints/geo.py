"""
AirGuard AI - Geographic Intelligence API Endpoints
Provides endpoints for spatial station discovery, geographic observations,
IDW spatial interpolation, pollution hotspot clusters, and network coverage.
"""
from typing import List, Optional
from fastapi import APIRouter, Query, HTTPException, status

from app.schemas.geo import (
    GeoCoverageResponse,
    GeoHeatmapResponse,
    GeoHotspotsResponse,
    GeoObservationItem,
    GeoStationItem,
    SpatialInterpolationResponse,
)
from app.services.geo_intelligence_service import geo_intelligence_service

router = APIRouter(prefix="/geo", tags=["Geographic Intelligence"])


@router.get(
    "/stations",
    response_model=List[GeoStationItem],
    summary="Geographic station discovery",
    description="Discover and deduplicate monitoring stations within a geographic search radius.",
)
async def get_geographic_stations(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=300.0, description="Search radius in kilometers"),
    include_demo: bool = Query(True, description="Whether to include synthetic demo fixtures"),
):
    try:
        return await geo_intelligence_service.get_geo_stations(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            include_demo=include_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query geographic stations: {str(e)}",
        )


@router.get(
    "/observations",
    response_model=List[GeoObservationItem],
    summary="Geographic air quality observations",
    description="Retrieve normalized air quality observations with CPCB AQI across stations in a region.",
)
async def get_geographic_observations(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=300.0, description="Search radius in kilometers"),
    include_demo: bool = Query(True, description="Whether to include synthetic demo fixtures"),
):
    try:
        return await geo_intelligence_service.get_geo_observations(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            include_demo=include_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query geographic observations: {str(e)}",
        )


@router.get(
    "/interpolation",
    response_model=SpatialInterpolationResponse,
    summary="Spatial pollutant interpolation (IDW)",
    description="Calculate Inverse Distance Weighting spatial interpolation for arbitrary coordinates.",
)
async def get_spatial_interpolation(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Target latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Target longitude in decimal degrees"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=200.0, description="Search radius in kilometers"),
    min_stations: Optional[int] = Query(None, ge=1, le=20, description="Minimum stations required"),
    allow_demo: bool = Query(False, description="Whether to permit demo fixtures for testing"),
):
    try:
        return await geo_intelligence_service.get_spatial_interpolation(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            min_stations=min_stations,
            allow_demo=allow_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to compute spatial interpolation: {str(e)}",
        )


@router.get(
    "/hotspots",
    response_model=GeoHotspotsResponse,
    summary="Pollution hotspot cluster detection",
    description="Identify spatial clusters of elevated pollution and classify severity.",
)
async def get_pollution_hotspots(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Center latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Center longitude in decimal degrees"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=200.0, description="Search radius in kilometers"),
    allow_demo: bool = Query(False, description="Whether to permit demo fixtures in hotspot detection"),
):
    try:
        return await geo_intelligence_service.get_hotspots(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            allow_demo=allow_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to detect pollution hotspots: {str(e)}",
        )


@router.get(
    "/heatmap",
    response_model=GeoHeatmapResponse,
    summary="Interpolated pollution heatmap grid",
    description=(
        "Builds a gridded interpolated surface (IDW) for AQI or a specific pollutant "
        "so the client can render a continuous heatmap over the search area."
    ),
)
async def get_pollution_heatmap(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Center latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Center longitude in decimal degrees"),
    pollutant: str = Query("AQI", description="AQI, PM2.5, PM10, NO2, SO2, CO, or O3"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=200.0, description="Search radius in kilometers"),
    grid_resolution: int = Query(14, ge=4, le=30, description="Number of grid cells per edge"),
    allow_demo: bool = Query(True, description="Whether to permit demo fixtures"),
):
    try:
        return await geo_intelligence_service.get_heatmap(
            latitude=latitude,
            longitude=longitude,
            pollutant=pollutant,
            radius_km=radius_km,
            grid_resolution=grid_resolution,
            allow_demo=allow_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to build pollution heatmap: {str(e)}",
        )


@router.get(
    "/coverage",
    response_model=GeoCoverageResponse,
    summary="Geographic monitoring coverage assessment",
    description="Assess sensor coverage quality, spatial density, and active monitoring capabilities.",
)
async def get_geographic_coverage(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Center latitude in decimal degrees"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Center longitude in decimal degrees"),
    radius_km: Optional[float] = Query(None, ge=1.0, le=300.0, description="Search radius in kilometers"),
    include_demo: bool = Query(True, description="Whether to include synthetic demo fixtures"),
):
    try:
        return await geo_intelligence_service.get_coverage_assessment(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            include_demo=include_demo,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to evaluate geographic coverage: {str(e)}",
        )
