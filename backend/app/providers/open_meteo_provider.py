"""
AirGuard AI - Open-Meteo Air Quality Provider Adapter
Delivers high-resolution atmospheric chemical transport model data.
Strict Data Integrity Rule: Classified as ESTIMATED (current model) or FORECAST (future model steps), NEVER LIVE.
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


class OpenMeteoProvider(BaseAirQualityProvider):
    @property
    def name(self) -> str:
        return "open_meteo"

    @property
    def display_name(self) -> str:
        return "Open-Meteo Air Quality (Atmospheric Model)"

    @property
    def data_source_type(self) -> DataSourceType:
        return DataSourceType.ESTIMATED

    @property
    def supported_pollutants(self) -> List[str]:
        return ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"]

    @property
    def attribution(self) -> str:
        return "Data provided by Open-Meteo.com under Non-Commercial / Attribution Creative Commons."

    async def check_health(self) -> ProviderStatusItem:
        start_time = time.time()
        test_url = (
            f"{settings.OPEN_METEO_AIR_BASE_URL}/air-quality"
            "?latitude=28.6139&longitude=77.2090&current=pm2_5"
        )
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.get(test_url)
                latency = round((time.time() - start_time) * 1000.0, 1)
                if res.status_code == 200:
                    status = ProviderHealth.ONLINE
                    details = "Model API accessible without authentication (gridded chemical transport model)."
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
            requires_api_key=False,
            is_authenticated=True,
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
        """
        Open-Meteo is a gridded model, not discrete physical stations.
        We provide a representative regional grid station at the query coordinate.
        """
        station_id = f"METEO-GRID-{latitude:.2f}-{longitude:.2f}"
        return [
            MonitoringStationSummary(
                station_id=station_id,
                station_name=f"Open-Meteo Regional Model Grid ({latitude:.2f}°N, {longitude:.2f}°E)",
                provider=self.display_name,
                location=LocationCoordinate(
                    latitude=latitude,
                    longitude=longitude,
                    city=f"Grid ({latitude:.2f}, {longitude:.2f})",
                    country="India",
                ),
                distance_km=0.0,
                available_pollutants=self.supported_pollutants,
                data_source_type=DataSourceType.ESTIMATED,
                is_active=True,
                last_reported_at=datetime.now(timezone.utc),
            )
        ]

    async def get_station_details(
        self, station_id: str
    ) -> Optional[MonitoringStationSummary]:
        if not station_id.startswith("METEO-GRID-"):
            return None
        parts = station_id.replace("METEO-GRID-", "").split("-")
        if len(parts) == 2:
            try:
                lat = float(parts[0])
                lon = float(parts[1])
                return MonitoringStationSummary(
                    station_id=station_id,
                    station_name=f"Open-Meteo Regional Model Grid ({lat:.2f}°N, {lon:.2f}°E)",
                    provider=self.display_name,
                    location=LocationCoordinate(
                        latitude=lat,
                        longitude=lon,
                        city=f"Grid ({lat:.2f}, {lon:.2f})",
                        country="India",
                    ),
                    distance_km=None,
                    available_pollutants=self.supported_pollutants,
                    data_source_type=DataSourceType.ESTIMATED,
                    is_active=True,
                    last_reported_at=datetime.now(timezone.utc),
                )
            except ValueError:
                pass
        return None

    async def get_current_observation(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[EnvironmentalObservationInput]:
        lat = latitude
        lon = longitude
        if station_id and station_id.startswith("METEO-GRID-"):
            parts = station_id.replace("METEO-GRID-", "").split("-")
            if len(parts) == 2:
                try:
                    lat = float(parts[0])
                    lon = float(parts[1])
                except ValueError:
                    pass

        if lat is None or lon is None:
            return None

        url = (
            f"{settings.OPEN_METEO_AIR_BASE_URL}/air-quality"
            f"?latitude={lat}&longitude={lon}"
            "&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
            "&timezone=auto"
        )

        weather_url = (
            f"{settings.OPEN_METEO_WEATHER_BASE_URL}/forecast"
            f"?latitude={lat}&longitude={lon}"
            "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,surface_pressure"
            "&timezone=auto"
        )

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                air_res = await client.get(url)
                if air_res.status_code != 200:
                    return None
                air_data = air_res.json().get("current", {})

                # Try weather info
                temp, hum, wind, press = None, None, None, None
                try:
                    w_res = await client.get(weather_url)
                    if w_res.status_code == 200:
                        w_data = w_res.json().get("current", {})
                        temp = w_data.get("temperature_2m")
                        hum = w_data.get("relative_humidity_2m")
                        wind = w_data.get("wind_speed_10m")
                        press = w_data.get("surface_pressure")
                except Exception:
                    pass

                # Extract and normalize values
                # Open-Meteo returns CO in µg/m³; CPCB expects mg/m³
                raw_pm25 = air_data.get("pm2_5")
                raw_pm10 = air_data.get("pm10")
                raw_no2 = air_data.get("nitrogen_dioxide")
                raw_so2 = air_data.get("sulphur_dioxide")
                raw_co = air_data.get("carbon_monoxide")
                raw_o3 = air_data.get("ozone")

                pm25, _ = convert_and_validate_pollutant(PollutantType.PM2_5, raw_pm25, "µg/m³")
                pm10, _ = convert_and_validate_pollutant(PollutantType.PM10, raw_pm10, "µg/m³")
                no2, _ = convert_and_validate_pollutant(
                    PollutantType.NO2, raw_no2, "µg/m³", temperature_celsius=temp, pressure_hpa=press
                )
                so2, _ = convert_and_validate_pollutant(
                    PollutantType.SO2, raw_so2, "µg/m³", temperature_celsius=temp, pressure_hpa=press
                )
                co, _ = convert_and_validate_pollutant(
                    PollutantType.CO, raw_co, "µg/m³", temperature_celsius=temp, pressure_hpa=press
                )
                o3, _ = convert_and_validate_pollutant(
                    PollutantType.O3, raw_o3, "µg/m³", temperature_celsius=temp, pressure_hpa=press
                )

                time_str = air_data.get("time")
                if time_str:
                    try:
                        obs_time = datetime.fromisoformat(time_str)
                        if obs_time.tzinfo is None:
                            obs_time = obs_time.replace(tzinfo=timezone.utc)
                    except ValueError:
                        obs_time = datetime.now(timezone.utc)
                else:
                    obs_time = datetime.now(timezone.utc)

                return EnvironmentalObservationInput(
                    station_id=f"METEO-GRID-{lat:.2f}-{lon:.2f}",
                    station_name=f"Open-Meteo Regional Model ({lat:.2f}°N, {lon:.2f}°E)",
                    location=LocationCoordinate(
                        latitude=lat,
                        longitude=lon,
                        city=f"Grid ({lat:.2f}, {lon:.2f})",
                        country="India",
                    ),
                    timestamp=obs_time,
                    provider=self.display_name,
                    data_source_type=DataSourceType.ESTIMATED,
                    pm2_5=pm25,
                    pm10=pm10,
                    no2=no2,
                    so2=so2,
                    co=co,
                    o3=o3,
                    temperature_celsius=temp,
                    relative_humidity_pct=hum,
                    wind_speed_kmh=wind,
                )
        except Exception:
            return None

    async def get_historical_observations(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        lat, lon = 28.6139, 77.2090  # Default Delhi
        if station_id.startswith("METEO-GRID-"):
            parts = station_id.replace("METEO-GRID-", "").split("-")
            if len(parts) == 2:
                try:
                    lat = float(parts[0])
                    lon = float(parts[1])
                except ValueError:
                    pass

        url = (
            f"{settings.OPEN_METEO_AIR_BASE_URL}/air-quality"
            f"?latitude={lat}&longitude={lon}"
            "&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
            "&past_days=1&forecast_days=1&timezone=auto"
        )
        observations: List[EnvironmentalObservationInput] = []

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.get(url)
                if res.status_code != 200:
                    return []
                data = res.json().get("hourly", {})
                times = data.get("time", [])
                pm25_list = data.get("pm2_5", [])
                pm10_list = data.get("pm10", [])
                no2_list = data.get("nitrogen_dioxide", [])
                so2_list = data.get("sulphur_dioxide", [])
                co_list = data.get("carbon_monoxide", [])
                o3_list = data.get("ozone", [])

                now = datetime.now(timezone.utc)
                limit = min(hours, len(times))
                for i in range(len(times) - limit, len(times)):
                    try:
                        t_iso = times[i]
                        obs_time = datetime.fromisoformat(t_iso)
                        if obs_time.tzinfo is None:
                            obs_time = obs_time.replace(tzinfo=timezone.utc)
                    except Exception:
                        obs_time = datetime.now(timezone.utc)

                    # Strict Provenance Classification:
                    # If obs_time is in the future (> now + 5 min), classify as FORECAST
                    # Otherwise, classify as HISTORICAL
                    if obs_time > now:
                        data_type = DataSourceType.FORECAST
                    else:
                        data_type = DataSourceType.HISTORICAL

                    pm25, _ = convert_and_validate_pollutant(
                        PollutantType.PM2_5, pm25_list[i] if i < len(pm25_list) else None, "µg/m³"
                    )
                    pm10, _ = convert_and_validate_pollutant(
                        PollutantType.PM10, pm10_list[i] if i < len(pm10_list) else None, "µg/m³"
                    )
                    no2, _ = convert_and_validate_pollutant(
                        PollutantType.NO2, no2_list[i] if i < len(no2_list) else None, "µg/m³"
                    )
                    so2, _ = convert_and_validate_pollutant(
                        PollutantType.SO2, so2_list[i] if i < len(so2_list) else None, "µg/m³"
                    )
                    co, _ = convert_and_validate_pollutant(
                        PollutantType.CO, co_list[i] if i < len(co_list) else None, "µg/m³"
                    )
                    o3, _ = convert_and_validate_pollutant(
                        PollutantType.O3, o3_list[i] if i < len(o3_list) else None, "µg/m³"
                    )

                    observations.append(
                        EnvironmentalObservationInput(
                            station_id=station_id,
                            station_name=f"Open-Meteo Regional Model ({lat:.2f}°N, {lon:.2f}°E)",
                            location=LocationCoordinate(latitude=lat, longitude=lon, city="Grid", country="India"),
                            timestamp=obs_time,
                            provider=self.display_name,
                            data_source_type=data_type,
                            pm2_5=pm25,
                            pm10=pm10,
                            no2=no2,
                            so2=so2,
                            co=co,
                            o3=o3,
                        )
                    )
        except Exception:
            pass

        return observations
