"""
AirGuard AI - Environmental Intelligence Service
Orchestrates multi-provider environmental data pipelines, caching, location discovery,
deterministic CPCB AQI calculation, and explainable risk evaluation.
"""
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from app.core.config import settings
from app.providers.base import BaseAirQualityProvider
from app.providers.openaq_provider import OpenAQProvider
from app.providers.open_meteo_provider import OpenMeteoProvider
from app.providers.cpcb_provider import CPCBDataGovProvider
from app.providers.demo_provider import DemoFixtureProvider
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.provider import (
    CurrentAirQualityResponse,
    LocationNearbyResponse,
    MonitoringStationSummary,
    ProviderStatusItem,
    ProviderStatusResponse,
)
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.risk_scoring import calculate_exposure_risk
from app.services.cache import cache
from app.services.geo import haversine_distance_km
from app.services.quality import check_observation_staleness


class EnvironmentalService:
    def __init__(self):
        self.providers: Dict[str, BaseAirQualityProvider] = {
            "openaq": OpenAQProvider(),
            "open_meteo": OpenMeteoProvider(),
            "cpcb_datagov": CPCBDataGovProvider(),
            "demo_fixtures": DemoFixtureProvider(),
        }

    async def get_providers_status(self) -> ProviderStatusResponse:
        cache_key = "providers:status"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        status_items: List[ProviderStatusItem] = []
        for provider in self.providers.values():
            try:
                item = await provider.check_health()
            except Exception as e:
                item = ProviderStatusItem(
                    name=provider.name,
                    display_name=provider.display_name,
                    status="OFFLINE",
                    requires_api_key=False,
                    is_authenticated=False,
                    primary_data_type=provider.data_source_type,
                    supported_pollutants=provider.supported_pollutants,
                    attribution=provider.attribution,
                    last_check_timestamp=datetime.now(timezone.utc),
                    latency_ms=0.0,
                    details=f"Health check exception: {str(e)}",
                )
            status_items.append(item)

        active = sum(1 for p in status_items if p.status in ("ONLINE", "CONFIGURED"))
        response = ProviderStatusResponse(
            providers=status_items,
            active_count=active,
            timestamp=datetime.now(timezone.utc),
        )

        await cache.set(cache_key, response, settings.CACHE_PROVIDER_STATUS_TTL_SECONDS)
        return response

    async def get_nearby_stations(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
        include_demo: bool = True,
    ) -> List[MonitoringStationSummary]:
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        radius = min(radius, settings.MAX_SEARCH_RADIUS_KM)

        cache_key = f"stations:{latitude:.2f}:{longitude:.2f}:{radius:.1f}:{include_demo}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        all_stations: List[MonitoringStationSummary] = []

        # 1. Query Live Ground Providers (OpenAQ, CPCB)
        for p_key in ("openaq", "cpcb_datagov"):
            provider = self.providers[p_key]
            try:
                res = await provider.get_nearby_stations(latitude, longitude, radius)
                all_stations.extend(res)
            except Exception:
                pass

        # 2. Add Open-Meteo regional model grid point
        meteo_provider = self.providers["open_meteo"]
        try:
            res = await meteo_provider.get_nearby_stations(latitude, longitude, radius)
            all_stations.extend(res)
        except Exception:
            pass

        # 3. Include Demo Fixtures if requested
        if include_demo:
            demo_provider = self.providers["demo_fixtures"]
            try:
                res = await demo_provider.get_nearby_stations(latitude, longitude, radius)
                all_stations.extend(res)
            except Exception:
                pass

        # Sort by distance
        all_stations.sort(key=lambda s: s.distance_km if s.distance_km is not None else 9999.0)

        await cache.set(cache_key, all_stations, settings.CACHE_STATIONS_TTL_SECONDS)
        return all_stations

    async def get_location_discovery(
        self,
        latitude: float,
        longitude: float,
        radius_km: Optional[float] = None,
    ) -> LocationNearbyResponse:
        radius = radius_km or settings.DEFAULT_SEARCH_RADIUS_KM
        stations = await self.get_nearby_stations(latitude, longitude, radius, include_demo=True)

        nearest = stations[0] if stations else None
        live_count = sum(1 for s in stations if s.data_source_type == DataSourceType.LIVE)

        if live_count > 0:
            msg = f"Discovered {live_count} live monitoring station(s) within {radius} km."
        elif nearest and nearest.data_source_type == DataSourceType.ESTIMATED:
            msg = f"No physical monitoring stations within {radius} km. Providing regional atmospheric transport model."
        else:
            msg = f"Station discovery complete. Showing nearest available monitoring points."

        query_loc = LocationCoordinate(
            latitude=latitude,
            longitude=longitude,
            city=nearest.location.city if nearest else "User GPS Location",
            country="India",
        )

        return LocationNearbyResponse(
            query_location=query_loc,
            search_radius_km=radius,
            nearest_station=nearest,
            nearby_stations=stations,
            message=msg,
        )

    async def get_station_by_id(self, station_id: str) -> Optional[MonitoringStationSummary]:
        cache_key = f"station:meta:{station_id}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        # Route to appropriate provider
        if station_id.startswith("OPENAQ-"):
            provider = self.providers["openaq"]
        elif station_id.startswith("METEO-GRID-"):
            provider = self.providers["open_meteo"]
        elif station_id.startswith("CPCB-"):
            provider = self.providers["cpcb_datagov"]
        elif station_id.startswith("DEMO-"):
            provider = self.providers["demo_fixtures"]
        else:
            provider = self.providers["demo_fixtures"]

        summary = await provider.get_station_details(station_id)
        if summary:
            await cache.set(cache_key, summary, settings.CACHE_STATIONS_TTL_SECONDS)
        return summary

    async def get_current_air_quality(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[CurrentAirQualityResponse]:
        cache_key = f"air:current:{station_id}:{latitude}:{longitude}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        obs: Optional[EnvironmentalObservationInput] = None
        station_summary: Optional[MonitoringStationSummary] = None

        # Route by station_id or coordinates
        if station_id:
            if station_id.startswith("OPENAQ-"):
                obs = await self.providers["openaq"].get_current_observation(station_id=station_id)
            elif station_id.startswith("METEO-GRID-"):
                obs = await self.providers["open_meteo"].get_current_observation(station_id=station_id)
            elif station_id.startswith("CPCB-"):
                obs = await self.providers["cpcb_datagov"].get_current_observation(station_id=station_id)
            elif station_id.startswith("DEMO-"):
                obs = await self.providers["demo_fixtures"].get_current_observation(station_id=station_id)

            station_summary = await self.get_station_by_id(station_id)

        elif latitude is not None and longitude is not None:
            # Query nearby stations
            nearby = await self.get_nearby_stations(latitude, longitude, settings.DEFAULT_SEARCH_RADIUS_KM)
            if nearby:
                target_station = nearby[0]
                station_id = target_station.station_id
                station_summary = target_station
                obs = await self._fetch_observation_for_station(target_station, latitude, longitude)
            else:
                # Fallback to Open-Meteo estimated model at coordinates
                obs = await self.providers["open_meteo"].get_current_observation(
                    latitude=latitude, longitude=longitude
                )
                if obs:
                    station_summary = MonitoringStationSummary(
                        station_id=obs.station_id or "METEO-GRID",
                        station_name=obs.station_name or "Open-Meteo Regional Model",
                        provider=obs.provider,
                        location=obs.location,
                        distance_km=0.0,
                        available_pollutants=["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"],
                        data_source_type=DataSourceType.ESTIMATED,
                        is_active=True,
                        last_reported_at=obs.timestamp,
                    )

        if not obs:
            return None

        # Calculate distance if user location provided
        dist_km = None
        if latitude is not None and longitude is not None:
            dist_km = haversine_distance_km(
                latitude, longitude, obs.location.latitude, obs.location.longitude
            )
            if station_summary and station_summary.distance_km is None:
                station_summary.distance_km = dist_km

        # Deterministic calculations
        aqi_result = calculate_cpcb_aqi(obs)
        risk_result = calculate_exposure_risk(aqi_result, obs)

        # Staleness evaluation
        is_stale, age_minutes = check_observation_staleness(obs.timestamp)

        response = CurrentAirQualityResponse(
            observation=obs,
            station=station_summary,
            distance_from_query_km=dist_km,
            aqi_result=aqi_result,
            risk_assessment=risk_result,
            data_freshness_minutes=age_minutes,
            is_stale=is_stale,
        )

        await cache.set(cache_key, response, settings.CACHE_OBSERVATIONS_TTL_SECONDS)
        return response

    async def _fetch_observation_for_station(
        self, station: MonitoringStationSummary, user_lat: float, user_lon: float
    ) -> Optional[EnvironmentalObservationInput]:
        st_id = station.station_id
        if st_id.startswith("OPENAQ-"):
            obs = await self.providers["openaq"].get_current_observation(station_id=st_id)
            if obs:
                return obs
        elif st_id.startswith("METEO-GRID-"):
            return await self.providers["open_meteo"].get_current_observation(station_id=st_id)
        elif st_id.startswith("DEMO-"):
            return await self.providers["demo_fixtures"].get_current_observation(station_id=st_id)

        # If live ground station returned no latest data, query model as fallback
        return await self.providers["open_meteo"].get_current_observation(
            latitude=station.location.latitude, longitude=station.location.longitude
        )

    async def get_air_history(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        cache_key = f"air:history:{station_id}:{hours}"
        cached = await cache.get(cache_key)
        if cached:
            return cached

        if station_id.startswith("METEO-GRID-"):
            obs_list = await self.providers["open_meteo"].get_historical_observations(
                station_id, hours
            )
        else:
            # Fallback to model history at station coordinates
            st = await self.get_station_by_id(station_id)
            if st:
                grid_id = f"METEO-GRID-{st.location.latitude:.2f}-{st.location.longitude:.2f}"
                obs_list = await self.providers["open_meteo"].get_historical_observations(
                    grid_id, hours
                )
            else:
                obs_list = []

        await cache.set(cache_key, obs_list, settings.CACHE_OBSERVATIONS_TTL_SECONDS)
        return obs_list


# Singleton service instance
environmental_service = EnvironmentalService()
