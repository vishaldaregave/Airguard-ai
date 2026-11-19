"""
AirGuard AI - Geographic Intelligence Schemas and Data Contracts
Defines schemas for spatial stations, geographic observations, IDW interpolation,
pollution hotspot clusters, and coverage quality metrics.
"""
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field, field_validator

from app.schemas.pollutant import DataSourceType, LocationCoordinate


class StationType(str, Enum):
    PHYSICAL_MONITOR = "PHYSICAL_MONITOR"
    ATMOSPHERIC_MODEL_GRID = "ATMOSPHERIC_MODEL_GRID"
    SYNTHETIC_FIXTURE = "SYNTHETIC_FIXTURE"


class InterpolationStatus(str, Enum):
    INTERPOLATED = "INTERPOLATED"
    INSUFFICIENT_STATIONS = "INSUFFICIENT_STATIONS"
    INSUFFICIENT_COVERAGE = "INSUFFICIENT_COVERAGE"
    STALE_INPUTS = "STALE_INPUTS"
    INVALID_INPUT = "INVALID_INPUT"


class HotspotSeverity(str, Enum):
    SEVERE_HOTSPOT = "SEVERE_HOTSPOT"
    VERY_POOR_HOTSPOT = "VERY_POOR_HOTSPOT"
    ELEVATED_CLUSTER = "ELEVATED_CLUSTER"
    ISOLATED_ELEVATED_READING = "ISOLATED_ELEVATED_READING"


class GeoStationItem(BaseModel):
    station_id: str = Field(..., description="Unique provider-scoped station identifier")
    station_name: str = Field(..., description="Official station display name")
    provider: str = Field(..., description="Data provider name (e.g., OpenAQ, CPCB)")
    station_type: StationType = Field(..., description="Physical monitor, model grid, or synthetic")
    location: LocationCoordinate = Field(..., description="Geographical location of station")
    distance_km: Optional[float] = Field(None, ge=0.0, description="Distance from reference coordinate in km")
    available_pollutants: List[str] = Field(default_factory=list, description="Monitored pollutant codes")
    data_source_type: DataSourceType = Field(..., description="LIVE, ESTIMATED, or DEMO_FIXTURE")
    is_active: bool = Field(True, description="Whether station is actively reporting")
    last_reported_at: Optional[datetime] = Field(None, description="Latest observation timestamp")


class GeoObservationItem(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: str = Field(..., description="Station display name")
    station_type: StationType = Field(..., description="PHYSICAL_MONITOR, ATMOSPHERIC_MODEL_GRID, or SYNTHETIC_FIXTURE")
    provider: str = Field(..., description="Data provider or monitoring agency name")
    location: LocationCoordinate = Field(..., description="Station coordinates")
    timestamp: datetime = Field(..., description="Observation timestamp in UTC")
    data_source_type: DataSourceType = Field(..., description="Data source type")
    
    # AQI metrics
    aqi: Optional[int] = Field(None, ge=0, description="Calculated CPCB IND-AQI index if eligible")
    cpcb_category: Optional[str] = Field(None, description="Official CPCB AQI category name")
    dominant_pollutant: Optional[str] = Field(None, description="Dominant criteria pollutant")

    # Pollutant concentrations (None means not monitored, never 0)
    pm2_5: Optional[float] = Field(None, ge=0.0, description="PM2.5 24-hr avg in µg/m³")
    pm10: Optional[float] = Field(None, ge=0.0, description="PM10 24-hr avg in µg/m³")
    no2: Optional[float] = Field(None, ge=0.0, description="NO2 24-hr avg in µg/m³")
    so2: Optional[float] = Field(None, ge=0.0, description="SO2 24-hr avg in µg/m³")
    co: Optional[float] = Field(None, ge=0.0, description="CO 8-hr avg in mg/m³")
    o3: Optional[float] = Field(None, ge=0.0, description="O3 8-hr avg in µg/m³")
    nh3: Optional[float] = Field(None, ge=0.0, description="NH3 24-hr avg in µg/m³")
    pb: Optional[float] = Field(None, ge=0.0, description="Lead (Pb) 24-hr avg in µg/m³")

    # Meteorological readings
    temperature_celsius: Optional[float] = Field(None, description="Ambient temperature in °C")
    relative_humidity_pct: Optional[float] = Field(None, ge=0.0, le=100.0, description="Relative humidity %")
    wind_speed_kmh: Optional[float] = Field(None, ge=0.0, description="Wind speed in km/h")

    # Quality and metadata
    pollutant_averaging_hours: Dict[str, int] = Field(
        default_factory=lambda: {
            "pm2_5": 24, "pm10": 24, "no2": 24, "so2": 24,
            "co": 8, "o3": 8, "nh3": 24, "pb": 24,
        },
        description="Averaging period per pollutant in hours",
    )
    pollutant_units: Dict[str, str] = Field(
        default_factory=lambda: {
            "pm2_5": "µg/m³", "pm10": "µg/m³", "no2": "µg/m³", "so2": "µg/m³",
            "co": "mg/m³", "o3": "µg/m³", "nh3": "µg/m³", "pb": "µg/m³",
        },
        description="Standard measurement unit per pollutant",
    )
    data_freshness_minutes: Optional[float] = Field(None, ge=0.0, description="Age of observation in minutes")
    is_stale: bool = Field(False, description="Flag indicating if observation exceeds staleness threshold")
    distance_km: Optional[float] = Field(None, ge=0.0, description="Distance from reference coordinate in km")


class ContributingStation(BaseModel):
    station_id: str = Field(..., description="Contributing station ID")
    station_name: str = Field(..., description="Contributing station display name")
    provider: str = Field(..., description="Provider name")
    station_type: StationType = Field(..., description="Physical monitor or model grid")
    distance_km: float = Field(..., ge=0.0, description="Distance to target point in km")
    weight: float = Field(..., ge=0.0, le=1.0, description="Normalized IDW weight assigned to this station")
    pollutant_value: float = Field(..., ge=0.0, description="Monitored pollutant concentration")
    averaging_hours: int = Field(..., description="Averaging period in hours")
    unit: str = Field(..., description="Measurement unit")
    data_source_type: DataSourceType = Field(..., description="Data source type")


class InterpolatedPollutant(BaseModel):
    pollutant: str = Field(..., description="Pollutant code (e.g. pm2_5, pm10)")
    estimated_value: float = Field(..., ge=0.0, description="Interpolated concentration")
    unit: str = Field(..., description="Concentration unit")
    averaging_hours: int = Field(..., description="Consistent averaging period in hours")
    sub_index: Optional[int] = Field(None, ge=0, description="CPCB sub-index calculated from estimated value")
    contributing_stations: List[ContributingStation] = Field(
        default_factory=list, description="Stations that contributed to this pollutant estimate"
    )


class SpatialInterpolationResponse(BaseModel):
    target_location: LocationCoordinate = Field(..., description="Query coordinate for interpolation")
    status: InterpolationStatus = Field(..., description="Interpolation execution status")
    data_source_type: DataSourceType = Field(
        DataSourceType.ESTIMATED, description="Interpolated values are always strictly ESTIMATED"
    )
    is_interpolated: bool = Field(True, description="Strictly true for all spatial interpolations")
    method: str = Field("INVERSE_DISTANCE_WEIGHTING", description="Spatial interpolation algorithm")
    power_parameter: float = Field(2.0, description="IDW distance power exponent (p)")
    search_radius_km: float = Field(..., ge=0.0, description="Search radius applied in km")
    interpolated_aqi: Optional[int] = Field(None, ge=0, description="Synthesized CPCB AQI if eligible")
    cpcb_category: Optional[str] = Field(None, description="Category of interpolated AQI")
    dominant_pollutant: Optional[str] = Field(None, description="Dominant pollutant determining AQI")
    pollutants: Dict[str, InterpolatedPollutant] = Field(
        default_factory=dict, description="Dictionary of interpolated pollutant estimates"
    )
    contributing_station_count: int = Field(..., ge=0, description="Total unique stations used")
    spatial_uncertainty_score: float = Field(
        ...,
        ge=0.0,
        le=100.0,
        description="Spatial uncertainty score (0-100, where higher indicates greater uncertainty)",
    )
    disclaimer: str = Field(
        "Estimated via Inverse Distance Weighting from nearby monitoring stations. "
        "Not an on-site physical measurement. Accuracy decreases with distance from physical sensors.",
        description="Mandatory scientific disclaimer",
    )
    timestamp: datetime = Field(..., description="Interpolation issuance timestamp in UTC")


class HotspotCluster(BaseModel):
    cluster_id: str = Field(..., description="Unique deterministic cluster identifier")
    center_location: LocationCoordinate = Field(..., description="Centroid coordinate of the pollution cluster")
    radius_km: float = Field(..., ge=0.0, description="Spatial span / bounding radius of cluster in km")
    severity: HotspotSeverity = Field(..., description="Classification of cluster severity")
    contributing_stations_count: int = Field(..., ge=1, description="Number of reporting stations in cluster")
    physical_stations_count: int = Field(default=1, ge=0, description="Count of physical ground monitors contributing")
    is_confirmed_hotspot: bool = Field(
        ..., description="True if confirmed by >= 2 stations. False if isolated single station"
    )
    peak_aqi: Optional[int] = Field(None, ge=0, description="Maximum observed AQI in cluster")
    mean_aqi: Optional[float] = Field(None, ge=0.0, description="Mean observed AQI across cluster stations")
    peak_pm2_5: Optional[float] = Field(None, ge=0.0, description="Maximum PM2.5 concentration in µg/m³")
    dominant_pollutant: Optional[str] = Field(None, description="Primary pollutant driving the cluster")
    data_source_type: DataSourceType = Field(..., description="Provenance of cluster data")
    contributing_stations: List[str] = Field(
        default_factory=list, description="IDs of stations contributing to this hotspot"
    )
    explanation: str = Field(..., description="Evidence and rationale for hotspot designation")
    disclaimer: str = Field(
        "Hotspot clusters represent spatial groupings of elevated station observations, "
        "not uniform dispersion plumes. Chain-connected clusters do not indicate uniform pollution "
        "across the entire bounding area.",
        description="Scientific interpretation disclaimer",
    )
    detected_at: datetime = Field(..., description="Timestamp of cluster detection in UTC")


class GeoHotspotsResponse(BaseModel):
    center_location: LocationCoordinate = Field(..., description="Query center coordinate")
    query_radius_km: float = Field(..., ge=0.0, description="Search radius queried in km")
    hotspots: List[HotspotCluster] = Field(default_factory=list, description="Identified hotspot clusters")
    total_hotspots_count: int = Field(..., ge=0, description="Number of hotspots found")
    timestamp: datetime = Field(..., description="Report generation timestamp in UTC")


class GeoCoverageResponse(BaseModel):
    center_location: LocationCoordinate = Field(..., description="Query center coordinate")
    search_radius_km: float = Field(..., ge=0.0, description="Search radius evaluated in km")
    total_stations: int = Field(..., ge=0, description="Total stations located within radius")
    physical_stations_count: int = Field(..., ge=0, description="Count of physical ground monitors")
    model_grid_points_count: int = Field(..., ge=0, description="Count of atmospheric model grid points")
    active_stations_count: int = Field(..., ge=0, description="Count of actively reporting stations")
    monitored_pollutant_counts: Dict[str, int] = Field(
        default_factory=dict, description="Number of active stations monitoring each pollutant"
    )
    nearest_station_km: Optional[float] = Field(None, ge=0.0, description="Distance to closest station in km")
    farthest_station_km: Optional[float] = Field(None, ge=0.0, description="Distance to farthest station in km")
    spatial_density_score: float = Field(
        ..., ge=0.0, le=100.0, description="Station spatial coverage density index (0-100)"
    )
    coverage_quality: str = Field(
        ..., description="Coverage assessment: EXCELLENT, GOOD, MODERATE, SPARSE, or INSUFFICIENT"
    )
    message: str = Field(..., description="Descriptive status of geographic coverage")
    timestamp: datetime = Field(..., description="Assessment timestamp in UTC")


class HeatmapCell(BaseModel):
    latitude: float = Field(..., description="Cell centroid latitude")
    longitude: float = Field(..., description="Cell centroid longitude")
    value: float = Field(..., ge=0.0, description="Interpolated pollutant concentration or AQI")
    confidence: float = Field(
        1.0,
        ge=0.0,
        le=1.0,
        description="Estimate reliability for this cell (decays with distance from the nearest station)",
    )


class GeoHeatmapResponse(BaseModel):
    center_location: LocationCoordinate = Field(..., description="Query center coordinate")
    pollutant: str = Field(..., description="Pollutant/AQI metric rendered on the heatmap")
    unit: str = Field(..., description="Measurement unit for the returned values")
    search_radius_km: float = Field(..., ge=0.0, description="Search radius covered by the grid")
    grid_resolution: int = Field(..., ge=2, description="Number of cells per grid edge")
    cells: List[HeatmapCell] = Field(
        default_factory=list, description="Interpolated grid cells, sparse when coverage is limited"
    )
    min_value: Optional[float] = Field(None, ge=0.0, description="Minimum interpolated value")
    max_value: Optional[float] = Field(None, ge=0.0, description="Maximum interpolated value")
    contributing_station_count: int = Field(..., ge=0, description="Stations used for interpolation")
    data_source_type: DataSourceType = Field(
        DataSourceType.ESTIMATED, description="Heatmap values are always ESTIMATED"
    )
    method: str = Field(
        "INVERSE_DISTANCE_WEIGHTING", description="Spatial interpolation algorithm"
    )
    disclaimer: str = Field(
        "Heatmap surfaces are interpolated estimates derived from monitoring stations, "
        "not continuous measurements. Regions far from stations carry higher uncertainty.",
        description="Mandatory scientific disclaimer",
    )
    timestamp: datetime = Field(..., description="Heatmap generation timestamp in UTC")
