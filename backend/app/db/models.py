"""
AirGuard AI - Database Models
Stores verified environmental observations and deterministic calculation results.
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
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    readings = relationship("StationObservation", back_populates="station", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_station_geo", "latitude", "longitude"),
    )


class StationObservation(Base):
    __tablename__ = "station_observations"

    id = Column(Integer, primary_key=True, index=True)
    station_id = Column(Integer, ForeignKey("monitoring_stations.id"), nullable=False, index=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    data_source_type = Column(String(32), nullable=False, default="LIVE")  # LIVE, HISTORICAL, DEMO_FIXTURE, etc.
    
    # Measured pollutant concentrations
    pm2_5 = Column(Float, nullable=True)
    pm10 = Column(Float, nullable=True)
    no2 = Column(Float, nullable=True)
    so2 = Column(Float, nullable=True)
    co = Column(Float, nullable=True)
    o3 = Column(Float, nullable=True)
    nh3 = Column(Float, nullable=True)
    pb = Column(Float, nullable=True)

    # Meteorological data
    temperature_celsius = Column(Float, nullable=True)
    relative_humidity_pct = Column(Float, nullable=True)
    wind_speed_kmh = Column(Float, nullable=True)

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
    )
