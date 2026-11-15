"""
AirGuard AI - Base Provider Interface
Abstract base class defining standardized contracts for environmental data providers.
"""
from abc import ABC, abstractmethod
from typing import List, Optional
from datetime import datetime

from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.provider import (
    MonitoringStationSummary,
    ProviderStatusItem,
)


class BaseAirQualityProvider(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        """Unique provider identifier."""
        pass

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Human-readable provider name."""
        pass

    @property
    @abstractmethod
    def data_source_type(self) -> DataSourceType:
        """Default provenance classification for this provider (LIVE, ESTIMATED, etc.)."""
        pass

    @property
    @abstractmethod
    def supported_pollutants(self) -> List[str]:
        """List of supported pollutants."""
        pass

    @property
    @abstractmethod
    def attribution(self) -> str:
        """Legal attribution requirement string."""
        pass

    @abstractmethod
    async def check_health(self) -> ProviderStatusItem:
        """Verifies operational status, connectivity, and authentication."""
        pass

    @abstractmethod
    async def get_nearby_stations(
        self, latitude: float, longitude: float, radius_km: float
    ) -> List[MonitoringStationSummary]:
        """Discovers monitoring stations within the specified geographic radius."""
        pass

    @abstractmethod
    async def get_station_details(
        self, station_id: str
    ) -> Optional[MonitoringStationSummary]:
        """Retrieves metadata for a specific station."""
        pass

    @abstractmethod
    async def get_current_observation(
        self,
        station_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Optional[EnvironmentalObservationInput]:
        """Retrieves latest normalized environmental observation."""
        pass

    @abstractmethod
    async def get_historical_observations(
        self, station_id: str, hours: int = 24
    ) -> List[EnvironmentalObservationInput]:
        """Retrieves historical observations for a station."""
        pass
