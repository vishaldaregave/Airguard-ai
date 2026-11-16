"""
AirGuard AI - Geographic Intelligence Orchestration Service
Unifies station discovery, geographic observations, IDW spatial interpolation,
pollution hotspot detection, and spatial coverage assessment.
"""
from datetime import datetime, timezone
import math
from typing import Dict, List, Optional, Tuple

from app.core.config import settings
from app.schemas.pollutant import DataSourceType, LocationCoordinate
from app.schemas.geo import (
    GeoCoverageResponse,
    GeoHotspotsResponse,
    GeoObservationItem,
    GeoStationItem,
    SpatialInterpolationResponse,
    StationType,
)
from app.services.environmental_service import EnvironmentalService
from app.services.geo import haversine_distance_km
from app.engine.spatial_interpolator import spatial_interpolator
from app.services.hotspot_service import hotspot_service
from app.services.cache import cache


class GeoIntelligenceService:
    def __init__(self, env_service: Optional[EnvironmentalService] = None):
        self.env_service = env_service or EnvironmentalService()

    def _determine_station_type(self, provider: str, data_source_type: DataSourceType) -> StationType:
        if data_source_type == DataSourceType.DEMO_FIXTURE:
            return StationType.SYNTHETIC_FIXTURE
        if "Meteo" in provider or "Model" in provider or data_source_type == DataSourceType.ESTIMATED:
            return StationType.ATMOSPHERIC_MODEL_GRID
        return StationType.PHYSICAL_MONITOR

    async def get_geo_stations(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        include_demo: bool = True,
    ) -> List[GeoStationItem]:
        """
        Discovers and deduplicates monitoring stations within a geographic radius.
        """
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        cache_key = f"geo:stations:{latitude:.3f}:{longitude:.3f}:{radius:.1f}:{include_demo}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        raw_stations = await self.env_service.get_nearby_stations(
            latitude, longitude, radius, include_demo=include_demo
        )

        dedup_map: Dict[str, GeoStationItem] = {}
        for s in raw_stations:
            composite_key = f"{s.provider}:{s.station_id}"
            if composite_key in dedup_map:
                continue

            station_type = self._determine_station_type(s.provider, s.data_source_type)
            dist = s.distance_km
            if dist is None:
                dist = haversine_distance_km(latitude, longitude, s.location.latitude, s.location.longitude)

            geo_item = GeoStationItem(
                station_id=s.station_id,
                station_name=s.station_name,
                provider=s.provider,
                station_type=station_type,
                location=s.location,
                distance_km=dist,
                available_pollutants=s.available_pollutants,
                data_source_type=s.data_source_type,
                is_active=s.is_active,
                last_reported_at=s.last_reported_at,
            )
            dedup_map[composite_key] = geo_item

        result = list(dedup_map.values())
        result.sort(key=lambda item: item.distance_km if item.distance_km is not None else 9999.0)

        await cache.set(cache_key, result, ttl_seconds=settings.CACHE_STATIONS_TTL_SECONDS)
        return result

    async def get_geo_observations(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        include_demo: bool = True,
    ) -> List[GeoObservationItem]:
        """
        Fetches current normalized observations and AQI for stations within a radius.
        """
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        cache_key = f"geo:obs:{latitude:.3f}:{longitude:.3f}:{radius:.1f}:{include_demo}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        stations = await self.get_geo_stations(latitude, longitude, radius, include_demo=include_demo)
        observations: List[GeoObservationItem] = []

        for st in stations:
            try:
                current_air = await self.env_service.get_current_air(
                    station_id=st.station_id,
                    latitude=st.location.latitude,
                    longitude=st.location.longitude,
                )
                obs_in = current_air.observation
                aqi_res = current_air.aqi_result

                geo_obs = GeoObservationItem(
                    station_id=st.station_id,
                    station_name=st.station_name,
                    station_type=st.station_type,
                    provider=st.provider,
                    location=st.location,
                    timestamp=obs_in.timestamp,
                    data_source_type=obs_in.data_source_type,
                    aqi=aqi_res.overall_aqi,
                    cpcb_category=aqi_res.category.value if aqi_res.category else None,
                    dominant_pollutant=(
                        aqi_res.prominent_pollutant.value
                        if hasattr(aqi_res.prominent_pollutant, "value")
                        else aqi_res.prominent_pollutant
                    ),
                    pm2_5=obs_in.pm2_5,
                    pm10=obs_in.pm10,
                    no2=obs_in.no2,
                    so2=obs_in.so2,
                    co=obs_in.co,
                    o3=obs_in.o3,
                    nh3=obs_in.nh3,
                    pb=obs_in.pb,
                    temperature_celsius=obs_in.temperature_celsius,
                    relative_humidity_pct=obs_in.relative_humidity_pct,
                    wind_speed_kmh=obs_in.wind_speed_kmh,
                    data_freshness_minutes=current_air.data_freshness_minutes,
                    is_stale=current_air.is_stale,
                    distance_km=st.distance_km,
                )
                observations.append(geo_obs)
            except Exception:
                # If individual station observation fails, omit gracefully without aborting entire spatial query
                continue

        await cache.set(cache_key, observations, ttl_seconds=settings.CACHE_OBSERVATIONS_TTL_SECONDS)
        return observations

    async def get_spatial_interpolation(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        min_stations: Optional[int] = None,
        allow_demo: bool = False,
    ) -> SpatialInterpolationResponse:
        """
        Executes IDW spatial interpolation for a requested target coordinate.
        """
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        # Retrieve observations (including demo fixtures only if allow_demo is set)
        observations = await self.get_geo_observations(
            latitude, longitude, radius_km=radius, include_demo=allow_demo
        )

        return spatial_interpolator.interpolate(
            target_lat=latitude,
            target_lon=longitude,
            observations=observations,
            allow_demo=allow_demo,
            search_radius_km=radius,
            min_stations=min_stations,
        )

    async def get_hotspots(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        allow_demo: bool = False,
    ) -> GeoHotspotsResponse:
        """
        Detects pollution hotspots in the geographic region around a coordinate.
        """
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        observations = await self.get_geo_observations(
            latitude, longitude, radius_km=radius, include_demo=allow_demo
        )

        return hotspot_service.detect_hotspots(
            center_lat=latitude,
            center_lon=longitude,
            query_radius_km=radius,
            observations=observations,
            allow_demo=allow_demo,
        )

    async def get_coverage_assessment(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        include_demo: bool = True,
    ) -> GeoCoverageResponse:
        """
        Evaluates spatial monitoring density, sensor counts, and coverage quality.
        """
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        stations = await self.get_geo_stations(latitude, longitude, radius, include_demo=include_demo)
        now_utc = datetime.now(timezone.utc)
        center_coord = LocationCoordinate(
            latitude=latitude,
            longitude=longitude,
            city="Coverage Center",
            country="India",
        )

        total_stations = len(stations)
        physical_count = sum(1 for s in stations if s.station_type == StationType.PHYSICAL_MONITOR)
        grid_count = sum(1 for s in stations if s.station_type == StationType.ATMOSPHERIC_MODEL_GRID)
        active_count = sum(1 for s in stations if s.is_active)

        # Monitored pollutant counts across stations
        pol_counts: Dict[str, int] = {}
        for s in stations:
            for p in s.available_pollutants:
                pol_counts[p] = pol_counts.get(p, 0) + 1

        distances = [s.distance_km for s in stations if s.distance_km is not None]
        nearest_d = min(distances) if distances else None
        farthest_d = max(distances) if distances else None

        # Spatial density calculation:
        # Expected optimal density: ~1 physical station per 25 km radius area (~2000 sq km)
        if total_stations == 0:
            density_score = 0.0
            quality = "INSUFFICIENT"
            msg = f"Zero monitoring stations discovered within {radius} km. No spatial coverage available."
        else:
            # Score factors: physical count, proximity of nearest station
            count_factor = min(1.0, physical_count / 5.0) * 60.0
            prox_factor = (max(0.0, 1.0 - (nearest_d / radius)) if nearest_d is not None else 0.0) * 40.0
            density_score = round(count_factor + prox_factor, 1)

            if physical_count >= 5 and (nearest_d is not None and nearest_d <= 10.0):
                quality = "EXCELLENT"
                msg = f"Dense physical monitoring network: {physical_count} ground stations within {radius} km."
            elif physical_count >= 3 and (nearest_d is not None and nearest_d <= 20.0):
                quality = "GOOD"
                msg = f"Adequate spatial coverage with {physical_count} physical ground monitors."
            elif physical_count >= 1 or grid_count >= 1:
                quality = "MODERATE"
                msg = f"Moderate coverage ({physical_count} physical, {grid_count} model grid points). Regional interpolation supported."
            else:
                quality = "SPARSE"
                msg = f"Sparse coverage within {radius} km. Measurements may have elevated spatial uncertainty."

        return GeoCoverageResponse(
            center_location=center_coord,
            search_radius_km=radius,
            total_stations=total_stations,
            physical_stations_count=physical_count,
            model_grid_points_count=grid_count,
            active_stations_count=active_count,
            monitored_pollutant_counts=pol_counts,
            nearest_station_km=nearest_d,
            farthest_station_km=farthest_d,
            spatial_density_score=density_score,
            coverage_quality=quality,
            message=msg,
            timestamp=now_utc,
        )


# Singleton instance
geo_intelligence_service = GeoIntelligenceService()
