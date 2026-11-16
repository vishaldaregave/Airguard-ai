"""
AirGuard AI - Database Models
Stores verified environmental observations, historical archives, forecast records,
and user alert preferences, device tokens, environmental notifications, and durable evaluation jobs.
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


class UserAlertPreference(Base):
    """Stores user environmental notification configurations and thresholds."""
    __tablename__ = "user_alert_preferences"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(64), unique=True, index=True, nullable=False)
    notifications_enabled = Column(Boolean, default=True, nullable=False)
    aqi_threshold = Column(Integer, default=200, nullable=False)
    pm25_threshold = Column(Float, default=60.0, nullable=False)
    pm10_threshold = Column(Float, default=100.0, nullable=False)
    sudden_deterioration_enabled = Column(Boolean, default=True, nullable=False)
    forecast_alerts_enabled = Column(Boolean, default=True, nullable=False)
    recovery_alerts_enabled = Column(Boolean, default=True, nullable=False)
    quiet_hours_enabled = Column(Boolean, default=False, nullable=False)
    quiet_hours_start = Column(Integer, default=22, nullable=False)  # 22:00 (10 PM)
    quiet_hours_end = Column(Integer, default=7, nullable=False)      # 07:00 (7 AM)
    preferred_station_code = Column(String(64), nullable=True)
    preferred_station_name = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class DeviceToken(Base):
    """Stores client device push notification tokens for FCM."""
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(64), index=True, nullable=False)
    token = Column(String(255), unique=True, index=True, nullable=False)
    device_type = Column(String(32), default="android", nullable=False)  # android, ios, web
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("idx_device_user_active", "user_id", "is_active"),
    )


class AlertRecord(Base):
    """Historical log of triggered environmental alerts."""
    __tablename__ = "alert_records"

    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(String(64), index=True, nullable=False)
    alert_type = Column(String(32), index=True, nullable=False)
    severity = Column(String(16), nullable=False)  # INFO, WARNING, DANGER, CRITICAL
    station_code = Column(String(64), index=True, nullable=False)
    station_name = Column(String(255), nullable=False)
    pollutant = Column(String(32), nullable=True)
    observed_value = Column(Float, nullable=True)
    threshold_value = Column(Float, nullable=True)
    unit = Column(String(16), default="µg/m³", nullable=False)
    source_provenance = Column(String(32), default="LIVE", nullable=False)
    observation_timestamp = Column(DateTime(timezone=True), nullable=False)
    trigger_reason = Column(Text, nullable=False)
    recommended_precaution = Column(Text, nullable=False)
    is_forecast = Column(Boolean, default=False, nullable=False)
    forecast_horizon_hours = Column(Integer, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False)
    is_resolved = Column(Boolean, default=False, nullable=False)
    delivery_status = Column(String(32), default="DELIVERED", nullable=False)  # DELIVERED, MOCK_DELIVERED, FAILED
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False, index=True)

    __table_args__ = (
        Index("idx_alert_user_time", "user_id", "created_at"),
        Index("idx_alert_user_read", "user_id", "is_read"),
    )


class AlertStateTracker(Base):
    """Tracks active alert state per user and station to govern cooldown, escalation, and recovery."""
    __tablename__ = "alert_state_trackers"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(64), index=True, nullable=False)
    station_code = Column(String(64), index=True, nullable=False)
    alert_type = Column(String(32), index=True, nullable=False)
    last_alert_id = Column(String(64), nullable=True)
    last_triggered_at = Column(DateTime(timezone=True), nullable=True)
    last_observed_value = Column(Float, nullable=True)
    last_severity = Column(String(16), nullable=True)
    is_active = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("idx_tracker_user_station_type", "user_id", "station_code", "alert_type", unique=True),
    )


class EvaluatedObservationLog(Base):
    """Records evaluated environmental observations to enforce worker idempotency."""
    __tablename__ = "evaluated_observation_logs"

    id = Column(Integer, primary_key=True, index=True)
    eval_hash = Column(String(64), unique=True, index=True, nullable=False)
    station_code = Column(String(64), index=True, nullable=False)
    observation_timestamp = Column(DateTime(timezone=True), index=True, nullable=False)
    evaluated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    revision = Column(Integer, default=0, nullable=False)
    is_correction = Column(Boolean, default=False, nullable=False)
    matched_subscriptions_count = Column(Integer, default=0, nullable=False)
    dispatched_alerts_count = Column(Integer, default=0, nullable=False)
    data_source_type = Column(String(32), default="LIVE", nullable=False)
    status = Column(String(32), default="COMPLETED", nullable=False)  # PROCESSING, COMPLETED

    __table_args__ = (
        Index("idx_eval_station_time", "station_code", "observation_timestamp"),
        Index("idx_eval_station_time_rev", "station_code", "observation_timestamp", "revision", unique=True),
    )


class AlertEvaluationJob(Base):
    """Durable queue for asynchronous background alert evaluations, surviving worker restarts."""
    __tablename__ = "alert_evaluation_jobs"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(String(64), unique=True, index=True, nullable=False)
    eval_hash = Column(String(64), index=True, nullable=False)
    station_code = Column(String(64), index=True, nullable=False)
    observation_timestamp = Column(DateTime(timezone=True), index=True, nullable=False)
    payload_json = Column(Text, nullable=False)
    status = Column(String(32), default="PENDING", index=True, nullable=False)  # PENDING, PROCESSING, COMPLETED, FAILED
    attempts = Column(Integer, default=0, nullable=False)
    max_retries = Column(Integer, default=3, nullable=False)
    last_error = Column(Text, nullable=True)
    scheduled_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    processed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("idx_job_status_scheduled", "status", "scheduled_at"),
        Index("idx_job_station_hash", "station_code", "eval_hash"),
    )
