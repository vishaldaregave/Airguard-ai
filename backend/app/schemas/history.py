"""
AirGuard AI - History Availability and Dataset Audit Schemas
Tracks data completeness, duration, and provenance distribution across the archive.
"""
from typing import Dict, List, Optional
from datetime import datetime
from pydantic import BaseModel, Field


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
