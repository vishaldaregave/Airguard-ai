"""
AirGuard AI - Exposure Intelligence Schemas and Data Contracts
Defines schemas for physical activity profiles, concentration-time exposure,
estimated inhaled mass, scenario comparison, and transparent scientific methodology.
"""
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field, field_validator

from app.schemas.pollutant import DataSourceType, LocationCoordinate


class ActivityType(str, Enum):
    RESTING = "resting"
    COMMUTING = "commuting"
    WALKING = "walking"
    CYCLING = "cycling"
    RUNNING = "running"


class ActivityProfile(BaseModel):
    activity_type: ActivityType = Field(..., description="Unique activity profile key")
    display_name: str = Field(..., description="Human-readable activity name")
    inhalation_rate_m3_h: float = Field(..., gt=0.0, description="Mean adult inhalation ventilation rate in m³/hour")
    met_equivalent: float = Field(..., gt=0.0, description="Metabolic Equivalent of Task (METs)")
    description: str = Field(..., description="Description of exertion level and typical physical state")
    reference: str = Field(..., description="Authoritative scientific literature citation")


class PollutantExposureMetric(BaseModel):
    pollutant: str = Field(..., description="Pollutant identifier (e.g., PM2.5, PM10, NO2, CO)")
    ambient_concentration: Optional[float] = Field(None, ge=0.0, description="Ambient pollutant concentration")
    concentration_unit: str = Field(..., description="Ambient concentration unit (e.g., µg/m³ or mg/m³ for CO)")
    concentration_time_exposure: Optional[float] = Field(
        None, ge=0.0, description="Cumulative concentration-time exposure (Concentration × Duration in hours)"
    )
    exposure_unit: str = Field(..., description="Concentration-time exposure unit (e.g., µg·h/m³ or mg·h/m³)")
    inhalation_rate_m3_h: float = Field(..., gt=0.0, description="Ventilation rate applied in m³/h")
    estimated_inhaled_mass: Optional[float] = Field(
        None, ge=0.0, description="Estimated gross inhaled pollutant mass (Concentration × Inhalation Rate × Duration)"
    )
    mass_unit: str = Field(..., description="Mass unit (e.g., µg or mg for CO)")
    is_available: bool = Field(True, description="Whether ambient observation was available (never coerced to 0)")


class SimulateExposureRequest(BaseModel):
    activity_type: ActivityType = Field(ActivityType.WALKING, description="Selected physical activity profile")
    duration_minutes: int = Field(60, ge=15, le=480, description="Exposure duration in minutes (15 to 480 minutes)")
    station_id: Optional[str] = Field(None, description="Monitoring station code to seed environmental data")
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0, description="Latitude coordinate")
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0, description="Longitude coordinate")
    use_interpolation: bool = Field(True, description="Whether to interpolate ambient air quality if station not found")
    use_forecast: bool = Field(False, description="Whether to simulate a future forecast window")
    forecast_start_offset_hours: int = Field(0, ge=0, le=24, description="Hours ahead for forecast exposure window")
    custom_concentrations: Optional[Dict[str, float]] = Field(
        None, description="Optional custom ambient concentrations for what-if simulation"
    )
    allow_demo: bool = Field(False, description="Whether to allow synthetic demo fixtures")

    @field_validator("duration_minutes")
    @classmethod
    def validate_duration(cls, v: int) -> int:
        if v < 15 or v > 480:
            raise ValueError("Duration must be between 15 minutes and 480 minutes (8 hours).")
        return v


class ExposureSimulationResponse(BaseModel):
    status: str = Field("COMPUTED", description="Simulation status: COMPUTED, INSUFFICIENT_DATA, STALE_DATA")
    activity: ActivityProfile = Field(..., description="Activity profile and ventilation parameters")
    duration_minutes: int = Field(..., description="Duration of exposure in minutes")
    duration_hours: float = Field(..., description="Duration of exposure in decimal hours")
    total_inhaled_volume_m3: float = Field(..., description="Total volume of air inhaled during duration (V_E × t)")
    data_source_type: DataSourceType = Field(..., description="Provenance: LIVE, ESTIMATED, FORECAST, DEMO_FIXTURE")
    location_name: str = Field(..., description="Location name or station identifier")
    latitude: Optional[float] = Field(None, description="Latitude coordinate")
    longitude: Optional[float] = Field(None, description="Longitude coordinate")
    pollutants: Dict[str, PollutantExposureMetric] = Field(
        default_factory=dict, description="Pollutant-specific exposure and inhaled mass metrics"
    )
    cpcb_aqi: Optional[int] = Field(None, description="CPCB IND-AQI corresponding to ambient air during window")
    cpcb_category: Optional[str] = Field(None, description="CPCB AQI Category")
    prominent_pollutant: Optional[str] = Field(None, description="Prominent criteria pollutant")
    is_forecast: bool = Field(False, description="Whether exposure is projected from a future forecast window")
    is_interpolated: bool = Field(False, description="Whether ambient concentration was spatially interpolated")
    spatial_uncertainty_score: Optional[float] = Field(None, description="Spatial uncertainty score if interpolated")
    calculation_methodology: str = Field(..., description="Transparent mathematical equations and scientific basis")
    disclaimer: str = Field(..., description="Non-medical, non-clinical scientific disclaimer")
    timestamp: datetime = Field(..., description="Simulation timestamp in UTC")


class PollutantComparisonDelta(BaseModel):
    pollutant: str = Field(..., description="Pollutant identifier")
    scenario_a_exposure: Optional[float] = Field(None, description="Scenario A concentration-time exposure")
    scenario_b_exposure: Optional[float] = Field(None, description="Scenario B concentration-time exposure")
    delta_exposure: Optional[float] = Field(None, description="Delta exposure (Scenario B - Scenario A)")
    exposure_unit: str = Field(..., description="Concentration-time unit (µg·h/m³ or mg·h/m³)")
    scenario_a_inhaled_mass: Optional[float] = Field(None, description="Scenario A estimated inhaled mass")
    scenario_b_inhaled_mass: Optional[float] = Field(None, description="Scenario B estimated inhaled mass")
    delta_inhaled_mass: Optional[float] = Field(None, description="Delta inhaled mass (Scenario B - Scenario A)")
    mass_unit: str = Field(..., description="Mass unit (µg or mg)")
    percent_change_inhaled_mass: Optional[float] = Field(
        None, description="Percentage change in inhaled mass from Scenario A to B"
    )
    summary: str = Field(..., description="Physical comparison summary for this pollutant")


class ScenarioComparisonItem(BaseModel):
    scenario_id: str = Field(..., description="Scenario identifier (scenario_a or scenario_b)")
    label: str = Field(..., description="User-assigned scenario label")
    simulation: ExposureSimulationResponse = Field(..., description="Complete simulation response")


class CompareExposureRequest(BaseModel):
    scenario_a: SimulateExposureRequest = Field(..., description="Parameters for baseline scenario A")
    scenario_b: SimulateExposureRequest = Field(..., description="Parameters for comparative scenario B")
    label_a: str = Field("Scenario A", description="Display label for Scenario A")
    label_b: str = Field("Scenario B", description="Display label for Scenario B")


class ExposureComparisonResponse(BaseModel):
    scenario_a: ScenarioComparisonItem = Field(..., description="Baseline Scenario A results")
    scenario_b: ScenarioComparisonItem = Field(..., description="Comparative Scenario B results")
    deltas: Dict[str, PollutantComparisonDelta] = Field(
        default_factory=dict, description="Pollutant-specific comparison deltas"
    )
    physical_comparison_summary: str = Field(
        ..., description="Objective physical comparison of duration, ventilation rates, and mass differences"
    )
    disclaimer: str = Field(..., description="Non-medical comparative advisory disclaimer")
    timestamp: datetime = Field(..., description="Comparison timestamp in UTC")


class ExposureExplanationRequest(BaseModel):
    simulation: ExposureSimulationResponse = Field(..., description="Simulation response to explain")
    user_query: Optional[str] = Field(None, description="Optional user inquiry regarding exposure")


class ExposureExplanationResponse(BaseModel):
    narrative: str = Field(..., description="AI or deterministic scientific explanation of exposure results")
    key_takeaways: List[str] = Field(default_factory=list, description="Core physical and environmental takeaways")
    protective_suggestions: List[str] = Field(
        default_factory=list, description="Actionable exposure mitigation suggestions"
    )
    methodology_note: str = Field(..., description="Clarification regarding ventilation rate assumptions and gross mass")
    disclaimer: str = Field(..., description="Non-medical scientific advisory disclaimer")
    provider: str = Field("Deterministic Rules Engine", description="Explanation provider name")
    timestamp: datetime = Field(..., description="Generation timestamp in UTC")
