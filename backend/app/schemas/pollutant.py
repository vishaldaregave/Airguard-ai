"""
AirGuard AI - Pollutant Data Contracts and Schemas
Strict data integrity: records provider, observation timestamp, units, and data source type.
"""
from enum import Enum
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class DataSourceType(str, Enum):
    LIVE = "LIVE"
    HISTORICAL = "HISTORICAL"
    ESTIMATED = "ESTIMATED"
    FORECAST = "FORECAST"
    DEMO_FIXTURE = "DEMO_FIXTURE"


class PollutantType(str, Enum):
    PM2_5 = "PM2.5"
    PM10 = "PM10"
    NO2 = "NO2"
    SO2 = "SO2"
    CO = "CO"
    O3 = "O3"
    NH3 = "NH3"
    PB = "PB"


class PollutantReading(BaseModel):
    pollutant: PollutantType = Field(..., description="Type of atmospheric pollutant")
    value: float = Field(..., description="Measured concentration value")
    unit: str = Field(..., description="Measurement unit (e.g. µg/m³ or mg/m³ for CO)")
    averaging_period_hours: int = Field(
        ...,
        description="Averaging period in hours (e.g., 24 for PM2.5/PM10/NO2/SO2/NH3, 8 for CO/O3)"
    )

    @field_validator("value")
    @classmethod
    def validate_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Pollutant concentration cannot be negative.")
        return v


class LocationCoordinate(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees")
    city: Optional[str] = Field(None, description="City name")
    state: Optional[str] = Field(None, description="State/Province name")
    country: str = Field("India", description="Country name")


class EnvironmentalObservationInput(BaseModel):
    station_id: Optional[str] = Field(None, description="Monitoring station identifier if available")
    station_name: Optional[str] = Field(None, description="Monitoring station name")
    location: LocationCoordinate = Field(..., description="Geographical coordinates")
    timestamp: datetime = Field(..., description="Observation timestamp in ISO 8601 format")
    provider: str = Field(..., description="Data provider or monitoring agency name")
    data_source_type: DataSourceType = Field(
        ...,
        description="Type of data: LIVE, HISTORICAL, ESTIMATED, FORECAST, or DEMO_FIXTURE"
    )
    
    # Individual pollutant concentrations (None means NOT MONITORED, never interpret as 0)
    pm2_5: Optional[float] = Field(None, ge=0.0, description="PM2.5 24-hr avg in µg/m³")
    pm10: Optional[float] = Field(None, ge=0.0, description="PM10 24-hr avg in µg/m³")
    no2: Optional[float] = Field(None, ge=0.0, description="NO2 24-hr avg in µg/m³")
    so2: Optional[float] = Field(None, ge=0.0, description="SO2 24-hr avg in µg/m³")
    co: Optional[float] = Field(None, ge=0.0, description="CO 8-hr avg in mg/m³")
    o3: Optional[float] = Field(None, ge=0.0, description="O3 8-hr avg in µg/m³")
    nh3: Optional[float] = Field(None, ge=0.0, description="NH3 24-hr avg in µg/m³")
    pb: Optional[float] = Field(None, ge=0.0, description="Lead (Pb) 24-hr avg in µg/m³")

    # Optional meteorological readings (for explainable exposure risk compounding)
    temperature_celsius: Optional[float] = Field(None, description="Ambient temperature in °C")
    relative_humidity_pct: Optional[float] = Field(None, ge=0.0, le=100.0, description="Relative humidity %")
    wind_speed_kmh: Optional[float] = Field(None, ge=0.0, description="Wind speed in km/h")
