"""
AirGuard AI - Environmental Alert Data Contracts and Schemas
Strict validation for thresholds, quiet hours, alert severity, and notification state.
"""
from enum import Enum
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class AlertSeverity(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    DANGER = "DANGER"
    CRITICAL = "CRITICAL"


class AlertType(str, Enum):
    AQI_THRESHOLD = "AQI_THRESHOLD"
    PM25_THRESHOLD = "PM25_THRESHOLD"
    PM10_THRESHOLD = "PM10_THRESHOLD"
    SUDDEN_DETERIORATION = "SUDDEN_DETERIORATION"
    FORECAST_WARNING = "FORECAST_WARNING"
    DATA_FRESHNESS = "DATA_FRESHNESS"
    RECOVERY = "RECOVERY"


class DeviceType(str, Enum):
    ANDROID = "android"
    IOS = "ios"
    WEB = "web"


class UserAlertPreferenceInput(BaseModel):
    notifications_enabled: bool = Field(True, description="Master toggle for environmental alerts")
    aqi_threshold: int = Field(200, ge=1, le=500, description="CPCB AQI notification threshold (1-500)")
    pm25_threshold: float = Field(60.0, ge=1.0, le=1000.0, description="PM2.5 concentration threshold in µg/m³")
    pm10_threshold: float = Field(100.0, ge=1.0, le=1000.0, description="PM10 concentration threshold in µg/m³")
    sudden_deterioration_enabled: bool = Field(True, description="Alert if AQI spikes significantly in short time")
    forecast_alerts_enabled: bool = Field(True, description="Enable warnings based on verified forecast horizons")
    recovery_alerts_enabled: bool = Field(True, description="Notify when conditions recover below threshold")
    quiet_hours_enabled: bool = Field(False, description="Enable quiet hours to suppress notification dispatch")
    quiet_hours_start: int = Field(22, ge=0, le=23, description="Quiet hours start hour in 24-hr format (0-23)")
    quiet_hours_end: int = Field(7, ge=0, le=23, description="Quiet hours end hour in 24-hr format (0-23)")
    preferred_station_code: Optional[str] = Field(None, description="Preferred monitoring station identifier")
    preferred_station_name: Optional[str] = Field(None, description="Display name of preferred station")


class UserAlertPreferenceResponse(UserAlertPreferenceInput):
    user_id: str = Field(..., description="Unique user or client identifier")
    updated_at: datetime = Field(..., description="Timestamp when preferences were last modified")


class DeviceTokenRegisterRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=512, description="FCM device push registration token")
    device_type: DeviceType = Field(DeviceType.ANDROID, description="Client platform (android, ios, web)")


class DeviceTokenUnregisterRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=512, description="FCM device token to revoke")


class DeviceTokenResponse(BaseModel):
    status: str = Field(..., description="Operation outcome (e.g. REGISTERED, UNREGISTERED)")
    user_id: str = Field(..., description="Associated user ID")
    token: str = Field(..., description="Registered token")
    device_type: str = Field(..., description="Device operating platform")
    is_active: bool = Field(..., description="Token active state")


class AlertItem(BaseModel):
    alert_id: str = Field(..., description="Unique alert UUID")
    user_id: str = Field(..., description="Recipient user ID")
    alert_type: AlertType = Field(..., description="Triggered alert category")
    severity: AlertSeverity = Field(..., description="Alert urgency and risk classification")
    station_code: str = Field(..., description="Station or regional grid code")
    station_name: str = Field(..., description="Station display name")
    pollutant: Optional[str] = Field(None, description="Primary pollutant or AQI indicator")
    observed_value: Optional[float] = Field(None, description="Recorded or forecast value")
    threshold_value: Optional[float] = Field(None, description="Configured user trigger threshold")
    unit: str = Field("µg/m³", description="Measurement unit")
    source_provenance: str = Field("LIVE", description="Data provenance (LIVE, ESTIMATED, FORECAST)")
    observation_timestamp: datetime = Field(..., description="Timestamp of the environmental condition")
    trigger_reason: str = Field(..., description="Deterministic explanation of why alert fired")
    recommended_precaution: str = Field(..., description="Evidence-based precautionary guidance")
    is_forecast: bool = Field(False, description="True if alert is predictive, False if observed")
    forecast_horizon_hours: Optional[int] = Field(None, description="Horizon offset in hours if predictive")
    is_read: bool = Field(False, description="Read state in user alert inbox")
    is_resolved: bool = Field(False, description="True if environmental recovery occurred")
    delivery_status: str = Field("DELIVERED", description="FCM dispatch status: DELIVERED, MOCK_DELIVERED, FAILED")
    created_at: datetime = Field(..., description="Alert record creation timestamp")


class AlertListResponse(BaseModel):
    alerts: List[AlertItem] = Field(default_factory=list, description="List of alert records")
    total: int = Field(0, description="Total alerts count matching query")
    unread_count: int = Field(0, description="Number of unread alerts")


class AlertReadResponse(BaseModel):
    alert_id: str = Field(..., description="Updated alert UUID")
    is_read: bool = Field(True, description="Current read status")
    message: str = Field("Alert marked as read.", description="Outcome description")
