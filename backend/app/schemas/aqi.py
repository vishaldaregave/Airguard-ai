"""
AirGuard AI - AQI Calculation Response Schemas
Adheres strictly to CPCB IND-AQI standards.
"""
from enum import Enum
from typing import Dict, List, Optional
from datetime import datetime
from pydantic import BaseModel, Field
from app.schemas.pollutant import DataSourceType, LocationCoordinate


class AQICategory(str, Enum):
    GOOD = "Good"
    SATISFACTORY = "Satisfactory"
    MODERATE = "Moderate"
    POOR = "Poor"
    VERY_POOR = "Very Poor"
    SEVERE = "Severe"


class AQIColorCode(str, Enum):
    GOOD = "#00B050"          # Vivid Green
    SATISFACTORY = "#92D050"  # Light Green
    MODERATE = "#FFFF00"      # Yellow
    POOR = "#FF9900"          # Orange
    VERY_POOR = "#FF0000"     # Red
    SEVERE = "#C00000"        # Dark Red / Maroon


class CalculationStatus(str, Enum):
    VALID = "VALID"
    INSUFFICIENT_POLLUTANTS = "INSUFFICIENT_POLLUTANTS"
    STALE_DATA = "STALE_DATA"


class SubIndexResult(BaseModel):
    pollutant: str = Field(..., description="Pollutant identifier (e.g. PM2.5)")
    concentration: float = Field(..., description="Observed concentration value")
    unit: str = Field(..., description="Concentration measurement unit")
    sub_index: int = Field(..., ge=0, description="Calculated sub-index for this pollutant")
    category: AQICategory = Field(..., description="Category for this individual pollutant")
    breakpoint_low: float = Field(..., description="Lower concentration breakpoint")
    breakpoint_high: float = Field(..., description="Upper concentration breakpoint")
    index_low: int = Field(..., description="Lower index breakpoint")
    index_high: int = Field(..., description="Upper index breakpoint")
    averaging_period_hours: Optional[int] = Field(
        None, description="Official CPCB reference averaging period in hours (24h or 8h)"
    )


class HealthAdvisory(BaseModel):
    category: AQICategory
    general_statement: str = Field(..., description="CPCB official general health impact statement")
    sensitive_group_advice: str = Field(..., description="Actionable advice for vulnerable populations")
    outdoor_activity_advice: str = Field(..., description="Guidance on outdoor exercise and activity")
    recommended_mask: Optional[str] = Field(None, description="Guidance on protective respiratory wear")
    air_purifier_advice: Optional[str] = Field(None, description="Indoor air filtration guidance")


class AQICalculationResult(BaseModel):
    standard: str = Field("CPCB_INDIA", description="Methodology standard used (CPCB IND-AQI)")
    status: CalculationStatus = Field(..., description="Calculation status outcome")
    status_message: str = Field(..., description="Detailed explanation of the calculation status")
    
    overall_aqi: Optional[int] = Field(None, ge=0, le=500, description="Overall AQI value (max sub-index)")
    category: Optional[AQICategory] = Field(None, description="Overall CPCB air quality category")
    color_code: Optional[str] = Field(None, description="Hex color representation corresponding to category")
    prominent_pollutant: Optional[str] = Field(None, description="Pollutant driving the overall AQI")
    
    sub_indices: Dict[str, SubIndexResult] = Field(
        default_factory=dict,
        description="Dictionary of calculated sub-indices by pollutant"
    )
    monitored_pollutant_count: int = Field(..., description="Number of valid monitored pollutants evaluated")
    has_particulate_matter: bool = Field(..., description="Whether PM2.5 or PM10 was present (CPCB mandatory requirement)")
    
    health_advisory: Optional[HealthAdvisory] = Field(None, description="Official grounded health advisories")
    
    is_stale: bool = Field(False, description="Flag indicating if observation is older than threshold")
    data_source_type: DataSourceType = Field(..., description="Data provenance (LIVE, HISTORICAL, DEMO_FIXTURE, etc.)")
    provider: str = Field(..., description="Agency or provider of the environmental observation")
    observation_timestamp: datetime = Field(..., description="Timestamp when observation was captured")
    calculation_timestamp: datetime = Field(..., description="Timestamp when calculation was executed")
    location: LocationCoordinate = Field(..., description="Location of monitoring station/observation")
