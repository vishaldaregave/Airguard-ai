"""
AirGuard AI - Database Models
Stores verified environmental observations, historical archives, and forecast records.
Strict separation of provenance: LIVE, HISTORICAL, ESTIMATED, FORECAST, DEMO_FIXTURE.
"""
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    Float,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Text,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class MonitoringStation(Base):
    __tablename__ = "monitoring_stations"

    id = Column(Integer, primary_key=True, index=True)
    station_code = Column(String(64), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    city = Column(String(128), index=True, nullable=False)
    state = Column(String(128), index=True, nullable=False)
    country = Column(String(64), default="India", nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    provider = Column(String(128), nullable=False)
    data_source_type = Column(String(32), default="LIVE", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    readings = relationship("StationObservation", back_populates="station", cascade="all, delete-orphan")
    forecasts = relationship("ForecastRecord", back_populates="station", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_station_geo", "latitude", "longitude"),
    )


class StationObservation(Base):
    __tablename__ = "station_observations"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("monitoring_stations.id"), nullable=False, index=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    provider = Column(String(128), nullable=True)
    data_source_type = Column(String(32), nullable=False, default="LIVE")  # LIVE, HISTORICAL, ESTIMATED, DEMO_FIXTURE
    quality_flag = Column(String(32), nullable=False, default="VALID")      # VALID, STALE, SUSPECT, OUTLIER_REMOVED
    
    # Measured pollutant concentrations (µg/m³, except CO in mg/m³)
    pm2_5 = Column(Float, nullable=True)
    pm10 = Column(Float, nullable=True)
    no2 = Column(Float, nullable=True)
    so2 = Column(Float, nullable=True)
    co = Column(Float, nullable=True)
    o3 = Column(Float, nullable=True)
    nh3 = Column(Float, nullable=True)
    pb = Column(Float, nullable=True)

    # Meteorological variables
    temperature_celsius = Column(Float, nullable=True)
    relative_humidity_pct = Column(Float, nullable=True)
    wind_speed_kmh = Column(Float, nullable=True)
    wind_direction_deg = Column(Float, nullable=True)
    surface_pressure_hpa = Column(Float, nullable=True)
    precipitation_mm = Column(Float, nullable=True)

    # Deterministic calculation outcomes
    calculated_aqi = Column(Integer, nullable=True)
    aqi_category = Column(String(32), nullable=True)
    prominent_pollutant = Column(String(32), nullable=True)
    risk_score = Column(Integer, nullable=True)
    risk_level = Column(String(32), nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    station = relationship("MonitoringStation", back_populates="readings")

    __table_args__ = (
        Index("idx_station_timestamp", "station_id", "timestamp"),
        Index("idx_station_provenance", "station_id", "data_source_type"),
    )


class ForecastRecord(Base):
    __tablename__ = "forecast_records"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("monitoring_stations.id"), nullable=False, index=True)
    forecast_generated_at = Column(DateTime(timezone=True), nullable=False, index=True)
    target_timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    horizon_hours = Column(Integer, nullable=False)  # 1, 3, 6, 12, 24
    model_version = Column(String(64), nullable=False)
    data_source_type = Column(String(32), nullable=False, default="FORECAST")

    # Forecast pollutant concentrations
    predicted_pm2_5 = Column(Float, nullable=True)
    predicted_pm10 = Column(Float, nullable=True)
    predicted_no2 = Column(Float, nullable=True)
    predicted_so2 = Column(Float, nullable=True)
    predicted_co = Column(Float, nullable=True)
    predicted_o3 = Column(Float, nullable=True)

    # Statistical 95% prediction intervals (strictly calculated from out-of-fold empirical variance)
    pm2_5_lower_95 = Column(Float, nullable=True)
    pm2_5_upper_95 = Column(Float, nullable=True)
    pm10_lower_95 = Column(Float, nullable=True)
    pm10_upper_95 = Column(Float, nullable=True)

    # Deterministic forecast AQI from predicted criteria pollutants
    predicted_aqi = Column(Integer, nullable=True)
    predicted_aqi_category = Column(String(32), nullable=True)
    predicted_prominent_pollutant = Column(String(32), nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    station = relationship("MonitoringStation", back_populates="forecasts")

    __table_args__ = (
        Index("idx_forecast_target", "station_id", "target_timestamp"),
        Index("idx_forecast_gen_horizon", "station_id", "forecast_generated_at", "horizon_hours"),
    )
