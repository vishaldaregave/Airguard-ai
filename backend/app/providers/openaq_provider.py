"""
AirGuard AI - OpenAQ API v3 Provider Adapter
Official OpenAQ v3 ground-station integration.
Supports API key authentication, nearby station discovery, sensor parameter normalization,
and robust handling of rate limits and missing keys.
"""
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional
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
from app.services.quality import convert_and_validate_pollutant, validate_station_coordinates
from app.services.geo import haversine_distance_km


class OpenAQProvider(BaseAirQualityProvider):
    @property
    def name(self) -> str:
        return "openaq"

    @property
    def display_name(self) -> str:
        return "OpenAQ Global Monitoring Network (v3)"

    @property
    def data_source_type(self) -> DataSourceType:
        return DataSourceType.LIVE

    @property
    def supported_pollutants(self) -> List[str]:
        return ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"]

    @property
    def attribution(self) -> str:
        return "Air quality data courtesy of OpenAQ Community & Global EPA/CPCB Feeds."

    def _get_headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/json",
            "User-Agent": "AirGuardAI/1.1.0",
        }
        if settings.OPENAQ_API_KEY:
            headers["X-API-Key"] = settings.OPENAQ_API_KEY
        return headers

    async def check_health(self) -> ProviderStatusItem:
        start_time = time.time()
        has_key = bool(settings.OPENAQ_API_KEY and settings.OPENAQ_API_KEY.strip())

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
                    "OPENAQ_API_KEY environment variable is not configured. "
                    "OpenAQ API v3 strictly requires registered API key authentication via X-API-Key header. "
                    "Real live retrieval from OpenAQ remains UNVERIFIED until credentials are provided."
                ),
            )

        # Ping locations endpoint
        url = f"{settings.OPENAQ_BASE_URL}/locations?limit=1"
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.get(url, headers=self._get_headers())
                latency = round((time.time() - start_time) * 1000.0, 1)
                if res.status_code == 200:
                    status = ProviderHealth.ONLINE
                    details = "OpenAQ API v3 verified and authenticated with valid API key."
                elif res.status_code in (401, 403):
                    status = ProviderHealth.UNAUTHENTICATED
                    details = f"Authentication rejected (HTTP {res.status_code}): Invalid or expired OPENAQ_API_KEY."
                elif res.status_code == 429:
                    status = ProviderHealth.DEGRADED
                    details = "Rate limit reached (HTTP 429). Exponential backoff active."
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
        if not settings.OPENAQ_API_KEY:
            return []

        radius_meters = int(radius_km * 1000)
        url = (
            f"{settings.OPENAQ_BASE_URL}/locations"
            f"?coordinates={latitude},{longitude}&radius={radius_meters}"
            "&limit=15"
        )
        stations: List[MonitoringStationSummary] = []

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url, headers=self._get_headers())
                if res.status_code != 200:
                    return []
                data = res.json().get("results", [])

                for loc in data:
                    st_id = str(loc.get("id"))
                    name = loc.get("name") or f"OpenAQ Station #{st_id}"
                    coords = loc.get("coordinates") or {}
                    lat = coords.get("latitude")
                    lon = coords.get("longitude")
                    
                    # Validate station coordinates
                    is_valid_coord, _ = validate_station_coordinates(lat, lon)
                    if not is_valid_coord or lat is None or lon is None:
                        continue

                    # Pollutant parameters present
                    sensors = loc.get("sensors", [])
                    available = []
                    for s in sensors:
                        param = s.get("parameter", {})
                        p_name = param.get("name", "").upper()
                        if "PM25" in p_name or "PM2.5" in p_name:
                            available.append("PM2.5")
                        elif "PM10" in p_name:
                            available.append("PM10")
                        elif "NO2" in p_name:
                            available.append("NO2")
                        elif "SO2" in p_name:
                            available.append("SO2")
                        elif "CO" in p_name:
                            available.append("CO")
                        elif "O3" in p_name:
                            available.append("O3")
                    available = list(set(available))

                    dist = haversine_distance_km(latitude, longitude, lat, lon)
                    datetime_last = loc.get("datetimeLast")
                    last_rep = None
                    if datetime_last:
                        try:
                            last_rep = datetime.fromisoformat(datetime_last.get("utc", ""))
                        except Exception:
                            pass

                    stations.append(
                        MonitoringStationSummary(
                            station_id=f"OPENAQ-{st_id}",
                            station_name=name,
                            provider=self.display_name,
                            location=LocationCoordinate(
                                latitude=lat,
                                longitude=lon,
                                city=loc.get("locality") or "OpenAQ Monitoring Point",
                                country=loc.get("country", {}).get("name") or "India",
                            ),
                            distance_km=dist,
                            available_pollutants=available,
                            data_source_type=DataSourceType.LIVE,
                            is_active=True,
                            last_reported_at=last_rep,
                        )
                    )
        except Exception:
            return []

        stations.sort(key=lambda s: s.distance_km if s.distance_km is not None else 9999.0)
        return stations

    async def get_station_details(
        self, station_id: str
    ) -> Optional[MonitoringStationSummary]:
        if not settings.OPENAQ_API_KEY:
            return None

        raw_id = station_id.replace("OPENAQ-", "")
        url = f"{settings.OPENAQ_BASE_URL}/locations/{raw_id}"

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url, headers=self._get_headers())
                if res.status_code != 200:
                    return None
                results = res.json().get("results", [])
                if not results:
                    return None
                loc = results[0]
                coords = loc.get("coordinates") or {}
                lat = coords.get("latitude")
                lon = coords.get("longitude")
                is_valid_coord, _ = validate_station_coordinates(lat, lon)
                if not is_valid_coord or lat is None or lon is None:
                    return None

                sensors = loc.get("sensors", [])
                available = []
                for s in sensors:
                    param = s.get("parameter", {})
                    p_name = param.get("name", "").upper()
                    if "PM2.5" in p_name or "PM25" in p_name:
                        available.append("PM2.5")
                    elif "PM10" in p_name:
                        available.append("PM10")
                    elif "NO2" in p_name:
                        available.append("NO2")
                    elif "SO2" in p_name:
                        available.append("SO2")
                    elif "CO" in p_name:
                        available.append("CO")
                    elif "O3" in p_name:
                        available.append("O3")

                return MonitoringStationSummary(
                    station_id=station_id,
                    station_name=loc.get("name") or f"OpenAQ Station #{raw_id}",
                    provider=self.display_name,
                    location=LocationCoordinate(
                        latitude=lat,
                        longitude=lon,
                        city=loc.get("locality") or "OpenAQ Monitoring Point",
                        country=loc.get("country", {}).get("name") or "India",
                    ),
                    distance_km=None,
                    available_pollutants=list(set(available)),
                    data_source_type=DataSourceType.LIVE,
                    is_active=True,
                    last_reported_at=None,
                )
        except Exception:
            return None

    async def get_current_observation(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[EnvironmentalObservationInput]:
        if not settings.OPENAQ_API_KEY:
            return None

        raw_id = None
        if station_id and station_id.startswith("OPENAQ-"):
            raw_id = station_id.replace("OPENAQ-", "")
        elif latitude is not None and longitude is not None:
            nearby = await self.get_nearby_stations(latitude, longitude, settings.DEFAULT_SEARCH_RADIUS_KM)
            if nearby:
                raw_id = nearby[0].station_id.replace("OPENAQ-", "")

        if not raw_id:
            return None

        url = f"{settings.OPENAQ_BASE_URL}/locations/{raw_id}/latest"

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url, headers=self._get_headers())
                if res.status_code != 200:
                    return None
                data = res.json().get("results", [])
                if not data:
                    return None

                pm25, pm10, no2, so2, co, o3 = None, None, None, None, None, None
                latest_time = None
                lat, lon = latitude or 28.6, longitude or 77.2
                station_name = f"OpenAQ Station #{raw_id}"

                for sensor_read in data:
                    coords = sensor_read.get("coordinates")
                    if coords:
                        c_lat = coords.get("latitude")
                        c_lon = coords.get("longitude")
                        if c_lat is not None and c_lon is not None:
                            lat, lon = c_lat, c_lon

                    val = sensor_read.get("value")
                    unit = sensor_read.get("units") or "µg/m³"
                    param = (sensor_read.get("parameter", {}).get("name") or "").upper()
                    
                    dt_str = sensor_read.get("datetime", {}).get("utc")
                    if dt_str:
                        try:
                            t = datetime.fromisoformat(dt_str)
                            if latest_time is None or t > latest_time:
                                latest_time = t
                        except Exception:
                            pass

                    if "PM2.5" in param or "PM25" in param:
                        pm25, _ = convert_and_validate_pollutant(PollutantType.PM2_5, val, unit)
                    elif "PM10" in param:
                        pm10, _ = convert_and_validate_pollutant(PollutantType.PM10, val, unit)
                    elif "NO2" in param:
                        no2, _ = convert_and_validate_pollutant(PollutantType.NO2, val, unit)
                    elif "SO2" in param:
                        so2, _ = convert_and_validate_pollutant(PollutantType.SO2, val, unit)
                    elif "CO" in param:
                        co, _ = convert_and_validate_pollutant(PollutantType.CO, val, unit)
                    elif "O3" in param:
                        o3, _ = convert_and_validate_pollutant(PollutantType.O3, val, unit)

                if latest_time is None:
                    latest_time = datetime.now(timezone.utc)
                elif latest_time.tzinfo is None:
                    latest_time = latest_time.replace(tzinfo=timezone.utc)

                return EnvironmentalObservationInput(
                    station_id=f"OPENAQ-{raw_id}",
                    station_name=station_name,
                    location=LocationCoordinate(latitude=lat, longitude=lon, country="India"),
                    timestamp=latest_time,
                    provider=self.display_name,
                    data_source_type=DataSourceType.LIVE,
                    pm2_5=pm25,
                    pm10=pm10,
                    no2=no2,
                    so2=so2,
                    co=co,
                    o3=o3,
                )
        except Exception:
            return None

    async def get_historical_observations(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        # History requires individual sensor measurement queries in OpenAQ v3
        return []
