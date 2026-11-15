"""
AirGuard AI - Provider and Station Schemas
Unified data contracts for provider abstraction, station discovery, and air quality status.
"""
from enum import Enum
from typing import Dict, List, Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
    PollutantType,
)
from app.schemas.aqi import AQICalculationResult
from app.schemas.risk import EnvironmentalRiskScore


class ProviderName(str, Enum):
    OPENAQ = "OpenAQ"
    OPEN_METEO = "Open-Meteo"
    CPCB_DATAGOV = "CPCB / data.gov.in"
    DEMO_FIXTURES = "AirGuard Demo Fixtures"


class ProviderHealth(str, Enum):
    ONLINE = "ONLINE"
    DEGRADED = "DEGRADED"
    UNAUTHENTICATED = "UNAUTHENTICATED"
    OFFLINE = "OFFLINE"
    CONFIGURED = "CONFIGURED"


class ProviderStatusItem(BaseModel):
    name: str = Field(..., description="Provider identifier")
    display_name: str = Field(..., description="Human-readable provider name")
    status: ProviderHealth = Field(..., description="Current operational status")
    requires_api_key: bool = Field(..., description="Whether provider requires authentication")
    is_authenticated: bool = Field(..., description="Whether valid API key is currently configured")
    primary_data_type: DataSourceType = Field(..., description="LIVE, ESTIMATED, or DEMO_FIXTURE")
    supported_pollutants: List[str] = Field(..., description="Pollutants supported by provider")
    attribution: str = Field(..., description="Mandatory attribution statement")
    last_check_timestamp: datetime = Field(..., description="Timestamp of status verification")
    latency_ms: Optional[float] = Field(None, description="Measured response time in milliseconds")
    details: Optional[str] = Field(None, description="Operational notes or limitations")


class ProviderStatusResponse(BaseModel):
    providers: List[ProviderStatusItem] = Field(..., description="List of configured environmental providers")
    active_count: int = Field(..., description="Count of active providers")
    timestamp: datetime = Field(..., description="Report generation timestamp")


class MonitoringStationSummary(BaseModel):
    station_id: str = Field(..., description="Unique provider-scoped station identifier")
    station_name: str = Field(..., description="Official station display name")
    provider: str = Field(..., description="Data provider name (e.g. OpenAQ, CPCB)")
    location: LocationCoordinate = Field(..., description="Geographical location of station")
    distance_km: Optional[float] = Field(None, description="Calculated distance from user in kilometers")
    available_pollutants: List[str] = Field(default_factory=list, description="List of pollutants monitored")
    data_source_type: DataSourceType = Field(..., description="LIVE, ESTIMATED, or DEMO_FIXTURE")
    is_active: bool = Field(True, description="Whether station is actively reporting")
    last_reported_at: Optional[datetime] = Field(None, description="Latest observation timestamp")


class LocationNearbyResponse(BaseModel):
    query_location: LocationCoordinate = Field(..., description="User coordinates queried")
    search_radius_km: float = Field(..., description="Radius searched in kilometers")
    nearest_station: Optional[MonitoringStationSummary] = Field(
        None, description="Nearest verified monitoring station"
    )
    nearby_stations: List[MonitoringStationSummary] = Field(
        default_factory=list, description="All stations found within search radius"
    )
    message: str = Field(..., description="Informational message about station coverage")


class CurrentAirQualityResponse(BaseModel):
    observation: EnvironmentalObservationInput = Field(..., description="Normalized environmental observation")
    station: Optional[MonitoringStationSummary] = Field(None, description="Monitoring station details")
    distance_from_query_km: Optional[float] = Field(
        None, description="Distance from user's GPS location to the monitoring station in km"
    )
    aqi_result: AQICalculationResult = Field(..., description="CPCB IND-AQI calculation result")
    risk_assessment: EnvironmentalRiskScore = Field(..., description="Explainable environmental risk score")
    data_freshness_minutes: Optional[float] = Field(None, description="Age of observation data in minutes")
    is_stale: bool = Field(False, description="Flag indicating if observation exceeds staleness threshold")


class AirQualityHistoryResponse(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: Optional[str] = Field(None, description="Station name")
    provider: str = Field(..., description="Provider name")
    data_source_type: DataSourceType = Field(..., description="LIVE, HISTORICAL, or ESTIMATED")
    count: int = Field(..., description="Number of historical data points")
    observations: List[EnvironmentalObservationInput] = Field(
        default_factory=list, description="Historical observations in chronological order"
    )
