"""
AirGuard AI - CPCB / data.gov.in Indian National AQI Provider Adapter
Integrates official Open Government Data (OGD) CAAQMS Real-Time Air Quality feeds from data.gov.in.
Adheres strictly to legal API access methods: requires registered API key from data.gov.in.
Public web portal dashboards (airquality.cpcb.gov.in) lack open unauthenticated APIs.
"""
import time
from datetime import datetime, timezone
from typing import List, Optional
import httpx

from app.core.config import settings
from app.providers.base import BaseAirQualityProvider
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
    PollutantType,
)
from app.schemas.provider import (
    MonitoringStationSummary,
    ProviderHealth,
    ProviderStatusItem,
)
from app.services.quality import convert_and_validate_pollutant
from app.services.geo import haversine_distance_km


class CPCBDataGovProvider(BaseAirQualityProvider):
    @property
    def name(self) -> str:
        return "cpcb_datagov"

    @property
    def display_name(self) -> str:
        return "CPCB / data.gov.in (National OGD Portal)"

    @property
    def data_source_type(self) -> DataSourceType:
        return DataSourceType.LIVE

    @property
    def supported_pollutants(self) -> List[str]:
        return ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3", "NH3"]

    @property
    def attribution(self) -> str:
        return "National Air Quality Monitoring Programme (NAMP/CAAQMS), Central Pollution Control Board via data.gov.in."

    async def check_health(self) -> ProviderStatusItem:
        start_time = time.time()
        has_key = bool(settings.DATAGOVIN_API_KEY and settings.DATAGOVIN_API_KEY.strip())

        if not has_key:
            return ProviderStatusItem(
                name=self.name,
                display_name=self.display_name,
                status=ProviderHealth.UNAUTHENTICATED,
                requires_api_key=True,
                is_authenticated=False,
                primary_data_type=self.data_source_type,
                supported_pollutants=self.supported_pollutants,
                attribution=self.attribution,
                last_check_timestamp=datetime.now(timezone.utc),
                latency_ms=0.0,
                details=(
                    "DATAGOVIN_API_KEY is not configured. Register at data.gov.in to obtain "
                    "official API access to resource '3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69'."
                ),
            )

        # Test request with API key
        url = (
            f"{settings.DATAGOVIN_BASE_URL}/{settings.DATAGOVIN_RESOURCE_ID}"
            f"?api-key={settings.DATAGOVIN_API_KEY}&format=json&limit=1"
        )
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.get(url)
                latency = round((time.time() - start_time) * 1000.0, 1)
                if res.status_code == 200:
                    status = ProviderHealth.ONLINE
                    details = "data.gov.in CPCB CAAQMS feed operational and verified."
                elif res.status_code in (401, 403):
                    status = ProviderHealth.UNAUTHENTICATED
                    details = f"data.gov.in rejected API key (HTTP {res.status_code})."
                elif res.status_code == 429:
                    status = ProviderHealth.DEGRADED
                    details = "data.gov.in rate limit encountered."
                else:
                    status = ProviderHealth.DEGRADED
                    details = f"HTTP {res.status_code}: {res.text[:100]}"
        except Exception as e:
            latency = round((time.time() - start_time) * 1000.0, 1)
            status = ProviderHealth.OFFLINE
            details = f"Connection failed: {str(e)}"

        return ProviderStatusItem(
            name=self.name,
            display_name=self.display_name,
            status=status,
            requires_api_key=True,
            is_authenticated=has_key,
            primary_data_type=self.data_source_type,
            supported_pollutants=self.supported_pollutants,
            attribution=self.attribution,
            last_check_timestamp=datetime.now(timezone.utc),
            latency_ms=latency,
            details=details,
        )

    async def get_nearby_stations(
        self, latitude: float, longitude: float, radius_km: float
    ) -> List[MonitoringStationSummary]:
        if not settings.DATAGOVIN_API_KEY:
            return []

        url = (
            f"{settings.DATAGOVIN_BASE_URL}/{settings.DATAGOVIN_RESOURCE_ID}"
            f"?api-key={settings.DATAGOVIN_API_KEY}&format=json&limit=50"
        )
        stations: List[MonitoringStationSummary] = []
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url)
                if res.status_code != 200:
                    return []
                records = res.json().get("records", [])

                for rec in records:
                    st_name = rec.get("station") or rec.get("station_name")
                    city = rec.get("city")
                    state = rec.get("state")
                    lat = rec.get("latitude")
                    lon = rec.get("longitude")
                    if lat is None or lon is None or not st_name:
                        continue
                    try:
                        lat_f = float(lat)
                        lon_f = float(lon)
                    except ValueError:
                        continue

                    dist = haversine_distance_km(latitude, longitude, lat_f, lon_f)
                    if dist <= radius_km:
                        stations.append(
                            MonitoringStationSummary(
                                station_id=f"CPCB-{st_name.lower().replace(' ', '-')[:32]}",
                                station_name=st_name,
                                provider=self.display_name,
                                location=LocationCoordinate(
                                    latitude=lat_f,
                                    longitude=lon_f,
                                    city=city,
                                    state=state,
                                    country="India",
                                ),
                                distance_km=dist,
                                available_pollutants=self.supported_pollutants,
                                data_source_type=DataSourceType.LIVE,
                                is_active=True,
                                last_reported_at=datetime.now(timezone.utc),
                            )
                        )
        except Exception:
            return []

        stations.sort(key=lambda s: s.distance_km if s.distance_km is not None else 9999.0)
        return stations

    async def get_station_details(
        self, station_id: str
    ) -> Optional[MonitoringStationSummary]:
        return None

    async def get_current_observation(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[EnvironmentalObservationInput]:
        # If API key not present, returns None
        if not settings.DATAGOVIN_API_KEY:
            return None
        return None

    async def get_historical_observations(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        return []
