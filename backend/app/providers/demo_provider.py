"""
AirGuard AI - Clearly Labeled Demo Fixture Provider
Strict Data Integrity Rule: Explicitly tagged as DEMO_FIXTURE.
Used for UI testing, development, and offline previewing. Never mixed with live data.
"""
from datetime import datetime, timezone
from typing import List, Optional

from app.providers.base import BaseAirQualityProvider
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.provider import (
    MonitoringStationSummary,
    ProviderHealth,
    ProviderStatusItem,
)
from app.services.geo import haversine_distance_km


class DemoFixtureProvider(BaseAirQualityProvider):
    @property
    def name(self) -> str:
        return "demo_fixtures"

    @property
    def display_name(self) -> str:
        return "AirGuard Synthetic Demo Fixtures"

    @property
    def data_source_type(self) -> DataSourceType:
        return DataSourceType.DEMO_FIXTURE

    @property
    def supported_pollutants(self) -> List[str]:
        return ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3", "NH3"]

    @property
    def attribution(self) -> str:
        return "Synthetic demonstration fixtures calibrated for UI evaluation."

    def _get_raw_fixtures(self) -> List[EnvironmentalObservationInput]:
        now = datetime.now(timezone.utc)
        return [
            EnvironmentalObservationInput(
                station_id="DEMO-DELHI-001",
                station_name="Anand Vihar, New Delhi [DEMO FIXTURE]",
                location=LocationCoordinate(
                    latitude=28.6508,
                    longitude=77.3152,
                    city="Delhi",
                    state="Delhi",
                    country="India",
                ),
                timestamp=now,
                provider="DPCC Demo Sensor Feed",
                data_source_type=DataSourceType.DEMO_FIXTURE,
                pm2_5=185.0,  # Very Poor
                pm10=310.0,   # Poor
                no2=95.0,     # Moderate
                so2=22.0,     # Good
                co=3.2,       # Moderate
                o3=45.0,      # Good
                nh3=85.0,     # Good
                temperature_celsius=19.5,
                relative_humidity_pct=82.0,
                wind_speed_kmh=4.2,
            ),
            EnvironmentalObservationInput(
                station_id="DEMO-MUMBAI-002",
                station_name="BKC, Bandra Kurla Complex [DEMO FIXTURE]",
                location=LocationCoordinate(
                    latitude=19.0657,
                    longitude=72.8687,
                    city="Mumbai",
                    state="Maharashtra",
                    country="India",
                ),
                timestamp=now,
                provider="MPCB Demo Sensor Feed",
                data_source_type=DataSourceType.DEMO_FIXTURE,
                pm2_5=68.0,   # Moderate
                pm10=115.0,   # Moderate
                no2=45.0,     # Satisfactory
                so2=14.0,     # Good
                co=1.4,       # Satisfactory
                o3=38.0,      # Good
                temperature_celsius=29.0,
                relative_humidity_pct=70.0,
                wind_speed_kmh=12.5,
            ),
            EnvironmentalObservationInput(
                station_id="DEMO-BLR-003",
                station_name="Silk Board, Bengaluru [DEMO FIXTURE]",
                location=LocationCoordinate(
                    latitude=12.9177,
                    longitude=77.6238,
                    city="Bengaluru",
                    state="Karnataka",
                    country="India",
                ),
                timestamp=now,
                provider="KSPCB Demo Sensor Feed",
                data_source_type=DataSourceType.DEMO_FIXTURE,
                pm2_5=24.0,   # Good
                pm10=42.0,    # Good
                no2=28.0,     # Good
                so2=8.0,      # Good
                co=0.8,       # Good
                o3=30.0,      # Good
                temperature_celsius=24.0,
                relative_humidity_pct=58.0,
                wind_speed_kmh=15.0,
            ),
            EnvironmentalObservationInput(
                station_id="DEMO-KOLKATA-004",
                station_name="Victoria Memorial, Kolkata [DEMO FIXTURE]",
                location=LocationCoordinate(
                    latitude=22.5448,
                    longitude=88.3426,
                    city="Kolkata",
                    state="West Bengal",
                    country="India",
                ),
                timestamp=now,
                provider="WBPCB Demo Sensor Feed",
                data_source_type=DataSourceType.DEMO_FIXTURE,
                pm2_5=280.0,  # Severe
                pm10=440.0,   # Severe
                no2=190.0,    # Poor
                so2=48.0,     # Satisfactory
                co=12.5,      # Poor
                o3=65.0,      # Satisfactory
                temperature_celsius=21.0,
                relative_humidity_pct=88.0,
                wind_speed_kmh=3.0,
            ),
        ]

    async def check_health(self) -> ProviderStatusItem:
        return ProviderStatusItem(
            name=self.name,
            display_name=self.display_name,
            status=ProviderHealth.ONLINE,
            requires_api_key=False,
            is_authenticated=True,
            primary_data_type=self.data_source_type,
            supported_pollutants=self.supported_pollutants,
            attribution=self.attribution,
            last_check_timestamp=datetime.now(timezone.utc),
            latency_ms=0.1,
            details="Demo fixtures available for UI testing.",
        )

    async def get_nearby_stations(
        self, latitude: float, longitude: float, radius_km: float
    ) -> List[MonitoringStationSummary]:
        fixtures = self._get_raw_fixtures()
        stations: List[MonitoringStationSummary] = []
        for f in fixtures:
            dist = haversine_distance_km(
                latitude, longitude, f.location.latitude, f.location.longitude
            )
            # If radius is large enough or fallback needed
            if dist <= radius_km:
                stations.append(
                    MonitoringStationSummary(
                        station_id=f.station_id or "DEMO-UNKNOWN",
                        station_name=f.station_name or "Demo Station",
                        provider=f.provider,
                        location=f.location,
                        distance_km=dist,
                        available_pollutants=self.supported_pollutants,
                        data_source_type=DataSourceType.DEMO_FIXTURE,
                        is_active=True,
                        last_reported_at=f.timestamp,
                    )
                )
        stations.sort(key=lambda s: s.distance_km if s.distance_km is not None else 9999.0)
        return stations

    async def get_station_details(
        self, station_id: str
    ) -> Optional[MonitoringStationSummary]:
        for f in self._get_raw_fixtures():
            if f.station_id == station_id:
                return MonitoringStationSummary(
                    station_id=f.station_id,
                    station_name=f.station_name or "Demo Station",
                    provider=f.provider,
                    location=f.location,
                    distance_km=None,
                    available_pollutants=self.supported_pollutants,
                    data_source_type=DataSourceType.DEMO_FIXTURE,
                    is_active=True,
                    last_reported_at=f.timestamp,
                )
        return None

    async def get_current_observation(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[EnvironmentalObservationInput]:
        fixtures = self._get_raw_fixtures()
        if station_id:
            for f in fixtures:
                if f.station_id == station_id:
                    return f
        if latitude is not None and longitude is not None:
            # Return nearest fixture
            closest = min(
                fixtures,
                key=lambda f: haversine_distance_km(
                    latitude, longitude, f.location.latitude, f.location.longitude
                ),
            )
            return closest
        return fixtures[0]

    async def get_historical_observations(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        return []
