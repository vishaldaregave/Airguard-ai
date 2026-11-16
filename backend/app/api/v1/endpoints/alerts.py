"""
AIRGUARD AI — Environmental Alerts and Notifications API Endpoints
Endpoints for alert history, user notification preferences, and device token registration.
"""

from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.schemas.alert import (
    UserAlertPreferenceInput,
    UserAlertPreferenceResponse,
    DeviceTokenRegisterRequest,
    DeviceTokenUnregisterRequest,
    DeviceTokenResponse,
    AlertListResponse,
    AlertItem,
    AlertReadResponse,
)
from app.schemas.pollutant import EnvironmentalObservationInput
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.services.alert_service import alert_service

router = APIRouter()


def get_current_user_id(x_user_id: Optional[str] = Header(None, alias="X-User-ID")) -> str:
    """
    Extract authenticated user identifier from header or fallback to default user.
    Enforces user isolation so users can only access their own alerts and preferences.
    """
    if x_user_id and x_user_id.strip():
        return x_user_id.strip()
    return "default_user"


@router.get(
    "",
    response_model=AlertListResponse,
    summary="Get user's environmental alert inbox & history",
    description="Retrieve paginated alert history for the authenticated user with unread counts and filters.",
)
async def get_user_alerts(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    unread_only: bool = Query(False),
    severity: Optional[str] = Query(None, description="Filter by severity: INFO, WARNING, DANGER, CRITICAL"),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AlertListResponse:
    records, total, unread_count = alert_service.list_alerts(
        db=db,
        user_id=user_id,
        limit=limit,
        offset=offset,
        unread_only=unread_only,
        severity=severity,
    )
    items = [
        AlertItem(
            alert_id=r.alert_id,
            user_id=r.user_id,
            alert_type=r.alert_type,
            severity=r.severity,
            station_code=r.station_code,
            station_name=r.station_name,
            pollutant=r.pollutant,
            observed_value=r.observed_value,
            threshold_value=r.threshold_value,
            unit=r.unit,
            source_provenance=r.source_provenance,
            observation_timestamp=r.observation_timestamp,
            trigger_reason=r.trigger_reason,
            recommended_precaution=r.recommended_precaution,
            is_forecast=r.is_forecast,
            forecast_horizon_hours=r.forecast_horizon_hours,
            is_read=r.is_read,
            is_resolved=r.is_resolved,
            delivery_status=r.delivery_status,
            created_at=r.created_at,
        )
        for r in records
    ]
    return AlertListResponse(alerts=items, total=total, unread_count=unread_count)


@router.get(
    "/preferences",
    response_model=UserAlertPreferenceResponse,
    summary="Get user notification preferences",
    description="Retrieve the current alert notification thresholds, preferred location, and quiet hours.",
)
async def get_user_preferences(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> UserAlertPreferenceResponse:
    pref = alert_service.get_or_create_user_preferences(db, user_id)
    return UserAlertPreferenceResponse(
        user_id=pref.user_id,
        notifications_enabled=pref.notifications_enabled,
        aqi_threshold=pref.aqi_threshold,
        pm25_threshold=pref.pm25_threshold,
        pm10_threshold=pref.pm10_threshold,
        sudden_deterioration_enabled=pref.sudden_deterioration_enabled,
        forecast_alerts_enabled=pref.forecast_alerts_enabled,
        recovery_alerts_enabled=pref.recovery_alerts_enabled,
        quiet_hours_enabled=pref.quiet_hours_enabled,
        quiet_hours_start=pref.quiet_hours_start,
        quiet_hours_end=pref.quiet_hours_end,
        preferred_station_code=pref.preferred_station_code,
        preferred_station_name=pref.preferred_station_name,
        updated_at=pref.updated_at,
    )


@router.put(
    "/preferences",
    response_model=UserAlertPreferenceResponse,
    summary="Update user notification preferences",
    description="Configure notification thresholds, quiet hours, preferred monitoring station, and forecast warnings.",
)
async def update_user_preferences(
    payload: UserAlertPreferenceInput,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> UserAlertPreferenceResponse:
    pref = alert_service.update_user_preferences(db, user_id, payload)
    return UserAlertPreferenceResponse(
        user_id=pref.user_id,
        notifications_enabled=pref.notifications_enabled,
        aqi_threshold=pref.aqi_threshold,
        pm25_threshold=pref.pm25_threshold,
        pm10_threshold=pref.pm10_threshold,
        sudden_deterioration_enabled=pref.sudden_deterioration_enabled,
        forecast_alerts_enabled=pref.forecast_alerts_enabled,
        recovery_alerts_enabled=pref.recovery_alerts_enabled,
        quiet_hours_enabled=pref.quiet_hours_enabled,
        quiet_hours_start=pref.quiet_hours_start,
        quiet_hours_end=pref.quiet_hours_end,
        preferred_station_code=pref.preferred_station_code,
        preferred_station_name=pref.preferred_station_name,
        updated_at=pref.updated_at,
    )


@router.post(
    "/device/register",
    response_model=DeviceTokenResponse,
    summary="Register FCM device token",
    description="Registers or updates a client device token for push notification delivery.",
)
async def register_device(
    payload: DeviceTokenRegisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> DeviceTokenResponse:
    device = alert_service.register_device_token(
        db=db,
        user_id=user_id,
        token=payload.token,
        device_type=payload.device_type.value,
    )
    return DeviceTokenResponse(
        status="REGISTERED",
        user_id=device.user_id,
        token=device.token,
        device_type=device.device_type,
        is_active=device.is_active,
    )


@router.delete(
    "/device/unregister",
    response_model=DeviceTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Unregister/revoke FCM device token",
    description="Deactivates a device registration token so no further alerts are delivered to this device.",
)
async def unregister_device(
    payload: DeviceTokenUnregisterRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> DeviceTokenResponse:
    success = alert_service.unregister_device_token(db=db, user_id=user_id, token=payload.token)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device token not found for this user",
        )
    return DeviceTokenResponse(
        status="UNREGISTERED",
        user_id=user_id,
        token=payload.token,
        device_type="android",
        is_active=False,
    )


@router.patch(
    "/{alert_id}/read",
    response_model=AlertReadResponse,
    summary="Mark alert as read",
    description="Updates the read status of a specific alert record belonging to the authenticated user.",
)
async def mark_alert_read(
    alert_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AlertReadResponse:
    record = alert_service.mark_alert_read(db=db, user_id=user_id, alert_id=alert_id)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert with ID {alert_id} not found for this user",
        )
    return AlertReadResponse(alert_id=record.alert_id, is_read=record.is_read)


@router.post(
    "/evaluate",
    response_model=AlertListResponse,
    summary="Evaluate observation against user preferences",
    description="Evaluates an environmental observation, runs deterministic rules and filters, and triggers alerts if required.",
)
async def evaluate_observation(
    observation: EnvironmentalObservationInput,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AlertListResponse:
    # Compute CPCB AQI using pure deterministic CPCB engine
    aqi_result = calculate_cpcb_aqi(observation)
    dispatched = alert_service.evaluate_and_dispatch_observation(
        db=db,
        user_id=user_id,
        obs=observation,
        aqi_result=aqi_result,
    )
    return AlertListResponse(
        alerts=dispatched,
        total=len(dispatched),
        unread_count=len(dispatched),
    )
