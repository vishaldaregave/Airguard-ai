"""
AirGuard AI - History Availability and Dataset Audit Schemas
Tracks data completeness, duration, and provenance distribution across the archive.
Expanded for Milestone 5.4: Historical Environmental Intelligence & Pollution Analytics.
"""
from typing import Dict, List, Optional, Any
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


# =========================================================================
# MILESTONE 3.1 & 3.2 DATASET AUDIT CONTRACTS (PRESERVED)
# =========================================================================

class DatasetProvenanceBreakdown(BaseModel):
    live_ground_records: int = Field(0, description="Physical monitoring station records (LIVE)")
    model_estimated_records: int = Field(0, description="Gridded chemical transport model records (ESTIMATED)")
    historical_archive_records: int = Field(0, description="Historical provider time-series records (HISTORICAL)")
    demo_fixture_records: int = Field(0, description="Synthetic demo fixtures (DEMO_FIXTURE)")


class HistoryAvailabilityResponse(BaseModel):
    total_records: int = Field(..., description="Total persisted environmental observation records")
    provenance_breakdown: DatasetProvenanceBreakdown = Field(..., description="Distribution across data sources")
    unique_stations_count: int = Field(..., description="Number of distinct stations or grid coordinates represented")
    earliest_observation: Optional[datetime] = Field(None, description="Oldest available observation timestamp in archive")
    latest_observation: Optional[datetime] = Field(None, description="Most recent observation timestamp in archive")
    duration_days: float = Field(0.0, description="Timespan covered by archive in decimal days")
    pollutant_completeness_pct: Dict[str, float] = Field(
        default_factory=dict,
        description="Percentage (0-100%) of records with valid non-null measurements per pollutant"
    )
    sufficient_for_ml_training: bool = Field(
        ..., description="Whether dataset meets minimum requirements (>= 48 continuous hours) for autoregressive ML"
    )
    active_forecasting_pipeline: str = Field(
        ..., description="Current operational pipeline: AUTOREGRESSIVE_RIDGE, SEASONAL_NAIVE, or PERSISTENCE"
    )
    audit_notes: str = Field(..., description="Methodological notes regarding dataset integrity and provenance separation")


# =========================================================================
# MILESTONE 5.4 HISTORICAL ANALYTICS ENUMS & CONTRACTS
# =========================================================================

class PeriodType(str, Enum):
    P24H = "24h"
    P7D = "7d"
    P30D = "30d"
    P90D = "90d"
    P1Y = "1y"

    @classmethod
    def to_hours(cls, period_str: str) -> int:
        clean = period_str.strip().lower()
        mapping = {
            "24h": 24,
            "7d": 168,
            "30d": 720,
            "90d": 2160,
            "1y": 8760,
        }
        return mapping.get(clean, 168)


class TrendDirection(str, Enum):
    INCREASING = "INCREASING"
    DECREASING = "DECREASING"
    STABLE = "STABLE"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"


class CalendarDayStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    PARTIAL_COVERAGE = "PARTIAL_COVERAGE"
    INSUFFICIENT_SAMPLES = "INSUFFICIENT_SAMPLES"
    UNAVAILABLE = "UNAVAILABLE"


class PollutantSummaryItem(BaseModel):
    pollutant: str = Field(..., description="Criteria pollutant name")
    mean: Optional[float] = Field(None, description="Arithmetic mean concentration")
    median: Optional[float] = Field(None, description="Median concentration")
    min_value: Optional[float] = Field(None, description="Minimum observed concentration")
    max_value: Optional[float] = Field(None, description="Peak observed concentration")
    standard_deviation: Optional[float] = Field(None, description="Standard deviation")
    valid_samples_count: int = Field(0, description="Count of valid non-null measurements")
    completeness_pct: float = Field(0.0, description="Completeness percentage (0-100%)")
    unit: str = Field(..., description="Measurement unit (e.g., µg/m³ or mg/m³ for CO)")
    averaging_period_hours: int = Field(24, description="Statutory regulatory averaging period in hours")
    statutory_standard_exceeded_count: int = Field(0, description="Samples exceeding CPCB standard threshold")


class HistoricalSummaryResponse(BaseModel):
    station_id: str = Field(..., description="Monitoring station identifier")
    station_name: str = Field(..., description="Human-readable station or grid location name")
    provider: str = Field(..., description="Environmental telemetry provider")
    data_source_type: str = Field(..., description="LIVE, ESTIMATED, HISTORICAL, or DEMO_FIXTURE")
    is_physical_station: bool = Field(True, description="True if ground monitor; False if atmospheric model grid")
    latitude: float = Field(..., description="Station latitude")
    longitude: float = Field(..., description="Station longitude")
    period: str = Field(..., description="Requested analysis period (24h, 7d, 30d, 90d, 1y)")
    start_time: datetime = Field(..., description="Start of historical observation window")
    end_time: datetime = Field(..., description="End of historical observation window")
    total_records: int = Field(..., description="Actual recorded observations in period")
    expected_samples: int = Field(..., description="Expected hourly observations in period")
    data_coverage_pct: float = Field(..., description="Observation coverage percentage")
    missing_intervals_count: int = Field(0, description="Count of data gap intervals (>2h without reading)")
    aqi_mean: Optional[float] = Field(None, description="Mean calculated CPCB AQI")
    aqi_median: Optional[float] = Field(None, description="Median calculated CPCB AQI")
    aqi_min: Optional[int] = Field(None, description="Minimum observed AQI")
    aqi_max: Optional[int] = Field(None, description="Peak observed AQI")
    aqi_std: Optional[float] = Field(None, description="Standard deviation of AQI")
    aqi_category_distribution: Dict[str, int] = Field(
        default_factory=dict, description="Count of observations per CPCB category (Good, Moderate, Poor, etc.)"
    )
    prominent_pollutant_dominance: Dict[str, int] = Field(
        default_factory=dict, description="Count of observations where pollutant was prominent"
    )
    pollutant_summaries: Dict[str, PollutantSummaryItem] = Field(
        default_factory=dict, description="Pollutant-specific statistical summaries"
    )
    overall_trend: TrendDirection = Field(TrendDirection.STABLE, description="Overall AQI trend direction")
    methodology_notes: str = Field(..., description="Transparent mathematical and aggregation methodology")
    disclaimer: str = Field(..., description="Scientific non-clinical environmental disclaimer")


class DataGapItem(BaseModel):
    start_time: datetime = Field(..., description="Start timestamp of missing interval")
    end_time: datetime = Field(..., description="End timestamp of missing interval")
    duration_hours: float = Field(..., description="Missing interval duration in decimal hours")
    reason: str = Field("Missing station telemetry", description="Explanation of observation gap")


class HistoricalDataPoint(BaseModel):
    timestamp: datetime = Field(..., description="Observation or bin timestamp")
    aqi: Optional[int] = Field(None, description="Calculated CPCB AQI")
    aqi_category: Optional[str] = Field(None, description="CPCB AQI Category")
    prominent_pollutant: Optional[str] = Field(None, description="Dominant criteria pollutant")
    pm2_5: Optional[float] = Field(None, description="PM2.5 concentration in µg/m³")
    pm10: Optional[float] = Field(None, description="PM10 concentration in µg/m³")
    no2: Optional[float] = Field(None, description="NO2 concentration in µg/m³")
    so2: Optional[float] = Field(None, description="SO2 concentration in µg/m³")
    co: Optional[float] = Field(None, description="CO concentration in mg/m³")
    o3: Optional[float] = Field(None, description="O3 concentration in µg/m³")
    temperature_celsius: Optional[float] = Field(None, description="Ambient temperature")
    wind_speed_kmh: Optional[float] = Field(None, description="Wind speed")
    sample_count: int = Field(1, description="Samples aggregated into this time point")
    is_gap: bool = Field(False, description="Flag indicating an unmonitored gap interval")


class HistoricalTrendsResponse(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Query period")
    data_source_type: str = Field(..., description="LIVE, ESTIMATED, HISTORICAL, DEMO_FIXTURE")
    is_physical_station: bool = Field(True, description="Physical monitor flag")
    trend_direction: TrendDirection = Field(..., description="Linear trend direction")
    slope_aqi_per_day: float = Field(0.0, description="Change in AQI per day (slope m)")
    r_squared: float = Field(0.0, description="Coefficient of determination R² (0.0 to 1.0)")
    p_value_significant: bool = Field(False, description="Whether linear slope is statistically significant")
    sample_count: int = Field(..., description="Total observation samples analyzed")
    aggregation_interval: str = Field("hourly", description="Aggregation bucket: hourly, 6-hourly, daily")
    time_points: List[HistoricalDataPoint] = Field(
        default_factory=list, description="Chronological time series points with gaps preserved"
    )
    data_gaps: List[DataGapItem] = Field(default_factory=list, description="Demarcated missing data intervals")
    diurnal_profile: Dict[int, Optional[float]] = Field(
        default_factory=dict, description="Mean AQI/PM2.5 for each hour of day (0-23)"
    )
    methodology_notes: str = Field(..., description="Linear regression and statistical significance thresholds")


class PollutantTrendItem(BaseModel):
    pollutant: str = Field(..., description="Pollutant name")
    unit: str = Field(..., description="Measurement unit")
    mean: Optional[float] = Field(None, description="Mean concentration")
    min: Optional[float] = Field(None, description="Minimum concentration")
    max: Optional[float] = Field(None, description="Peak concentration")
    trend_direction: TrendDirection = Field(..., description="Pollutant trend")
    slope_per_day: float = Field(0.0, description="Concentration delta per day")
    cpcb_standard_limit: Optional[float] = Field(None, description="CPCB 24-hr regulatory limit")
    exceedance_pct: float = Field(0.0, description="Percentage of samples exceeding standard limit")
    series: List[Dict[str, Any]] = Field(default_factory=list, description="Chronological timestamps and values")


class HistoricalPollutantsResponse(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Query period")
    pollutants: Dict[str, PollutantTrendItem] = Field(
        default_factory=dict, description="Comparative multi-pollutant trend series"
    )
    disclaimer: str = Field(..., description="Non-clinical scientific disclaimer")


class PeakEpisodeItem(BaseModel):
    episode_id: str = Field(..., description="Episode identifier")
    pollutant_or_metric: str = Field(..., description="AQI or pollutant driving the episode")
    peak_value: float = Field(..., description="Peak measured value during episode")
    start_time: datetime = Field(..., description="Episode start timestamp")
    peak_time: datetime = Field(..., description="Peak measurement timestamp")
    end_time: datetime = Field(..., description="Episode end timestamp")
    duration_hours: float = Field(..., description="Duration in hours")
    severity_category: str = Field(..., description="CPCB category or severity level")
    temperature_celsius: Optional[float] = Field(None, description="Co-occurring temperature")
    wind_speed_kmh: Optional[float] = Field(None, description="Co-occurring wind speed")
    humidity_pct: Optional[float] = Field(None, description="Co-occurring relative humidity")
    physical_description: str = Field(..., description="Objective physical description without unsupported causal claims")


class HistoricalExtremesResponse(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Query period")
    peak_episodes: List[PeakEpisodeItem] = Field(default_factory=list, description="Elevated pollution episodes")
    cleanest_periods: List[PeakEpisodeItem] = Field(default_factory=list, description="Lowest pollution windows")
    observations_insights: List[str] = Field(default_factory=list, description="Physical observation findings")
    disclaimer: str = Field(..., description="Non-causal non-clinical disclaimer")


class CalendarDayItem(BaseModel):
    date: str = Field(..., description="Calendar date in YYYY-MM-DD format")
    day_of_week: str = Field(..., description="Short day name (Mon, Tue, ...)")
    status: CalendarDayStatus = Field(..., description="Day availability status")
    representative_aqi: Optional[int] = Field(None, description="Day's representative CPCB AQI")
    aqi_category: Optional[str] = Field(None, description="CPCB category for the day")
    prominent_pollutant: Optional[str] = Field(None, description="Prominent pollutant for the day")
    sample_count: int = Field(0, description="Number of valid hourly samples recorded")
    daily_coverage_pct: float = Field(0.0, description="Hourly coverage (samples / 24 * 100)")
    is_cpcb_valid_day: bool = Field(False, description="True if >= 16 hourly samples as mandated by CPCB NAAQS")
    pollutant_means: Dict[str, Optional[float]] = Field(
        default_factory=dict, description="Daily mean concentration per criteria pollutant"
    )


class HistoricalCalendarResponse(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Query period")
    total_calendar_days: int = Field(..., description="Total days in the period")
    valid_days_count: int = Field(..., description="Days meeting CPCB 16-hour validity criteria")
    insufficient_days_count: int = Field(..., description="Days with sparse or missing telemetry")
    days: List[CalendarDayItem] = Field(default_factory=list, description="Daily historical records")
    cpcb_16_hour_rule_note: str = Field(
        ...,
        description="Statutory disclosure regarding the CPCB 16-hour minimum requirement for valid daily AQI"
    )


class HistoricalCompareItem(BaseModel):
    station_id: str = Field(..., description="Station identifier")
    label: str = Field(..., description="Display label (e.g., Location A)")
    station_name: str = Field(..., description="Station name")
    provider: str = Field(..., description="Provider name")
    data_source_type: str = Field(..., description="LIVE, ESTIMATED, HISTORICAL, DEMO_FIXTURE")
    is_physical_station: bool = Field(True, description="True if physical monitor")
    sample_count: int = Field(..., description="Observation count in period")
    data_coverage_pct: float = Field(..., description="Observation coverage percentage")
    mean_aqi: Optional[float] = Field(None, description="Mean AQI")
    peak_aqi: Optional[int] = Field(None, description="Peak AQI")
    pollutant_means: Dict[str, Optional[float]] = Field(
        default_factory=dict, description="Mean concentration per criteria pollutant"
    )
    aqi_category_distribution: Dict[str, int] = Field(default_factory=dict, description="Category distribution")


class HistoricalCompareRequest(BaseModel):
    station_id_a: str = Field(..., description="Station code for Location A")
    station_id_b: str = Field(..., description="Station code for Location B")
    period: str = Field("7d", description="Comparison period: 24h, 7d, 30d, 90d, 1y")
    label_a: str = Field("Location A", description="Display label for Location A")
    label_b: str = Field("Location B", description="Display label for Location B")


class HistoricalCompareResponse(BaseModel):
    period: str = Field(..., description="Comparison period")
    location_a: HistoricalCompareItem = Field(..., description="Location A summary")
    location_b: HistoricalCompareItem = Field(..., description="Location B summary")
    is_compatible: bool = Field(..., description="Whether datasets have compatible temporal resolution and provenance")
    compatibility_assessment: str = Field(..., description="Disclosure of compatibility, physical vs model differences")
    aqi_delta: Optional[float] = Field(None, description="Location B Mean AQI - Location A Mean AQI")
    pollutant_deltas: Dict[str, Optional[float]] = Field(
        default_factory=dict, description="Location B Mean - Location A Mean per pollutant"
    )
    comparative_summary: str = Field(..., description="Objective physical comparison narrative without medical claims")
    disclaimer: str = Field(..., description="Comparative environmental advisory disclaimer")


class HistoricalCoverageResponse(BaseModel):
    station_id: str = Field(..., description="Station code")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Query period")
    earliest_timestamp: Optional[datetime] = Field(None, description="Oldest observation in period")
    latest_timestamp: Optional[datetime] = Field(None, description="Newest observation in period")
    expected_samples: int = Field(..., description="Theoretical hourly observation count")
    actual_samples: int = Field(..., description="Actual recorded observation count")
    coverage_pct: float = Field(..., description="Percentage of expected observations present")
    gaps_count: int = Field(0, description="Total missing intervals (>2 hours without data)")
    longest_gap_hours: float = Field(0.0, description="Duration of longest continuous missing data window in hours")
    temporal_regularity_score: float = Field(100.0, description="Regularity score (0-100) penalized by gaps")
    gap_intervals: List[DataGapItem] = Field(default_factory=list, description="List of detected missing intervals")
    provenance_audit: Dict[str, int] = Field(default_factory=dict, description="Record counts by data source type")


class HistoricalReportResponse(BaseModel):
    title: str = Field(..., description="Environmental Intelligence Report Title")
    station_id: str = Field(..., description="Station code")
    station_name: str = Field(..., description="Station name")
    period: str = Field(..., description="Analyzed period")
    generated_at: datetime = Field(..., description="Report generation timestamp in UTC")
    executive_summary: str = Field(..., description="Concise non-clinical environmental executive summary")
    markdown_content: str = Field(..., description="Complete publication-ready markdown document")
    coverage_audit: HistoricalCoverageResponse = Field(..., description="Data completeness and gap audit")
    trend_analysis: Dict[str, Any] = Field(default_factory=dict, description="Summary trend statistics")
    disclaimer: str = Field(..., description="Mandatory non-clinical environmental disclaimer")


class HistoricalExplanationRequest(BaseModel):
    summary: HistoricalSummaryResponse = Field(..., description="Historical summary data to explain")
    trends: Optional[HistoricalTrendsResponse] = Field(None, description="Optional trend analytics")
    user_query: Optional[str] = Field(None, description="User question or focal inquiry")


class HistoricalExplanationResponse(BaseModel):
    narrative: str = Field(..., description="Objective explanation of observed historical patterns")
    key_insights: List[str] = Field(default_factory=list, description="Primary empirical takeaways")
    diurnal_observations: List[str] = Field(default_factory=list, description="Diurnal cycle patterns")
    data_limitations: List[str] = Field(default_factory=list, description="Coverage and missing data caveats")
    disclaimer: str = Field(..., description="Non-clinical disclaimer")
    provider: str = Field("AirGuard Evidence Explainer", description="Explainer engine identity")
    timestamp: datetime = Field(..., description="Generation timestamp in UTC")
