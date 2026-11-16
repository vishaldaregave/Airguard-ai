"""
AIRGUARD AI — Environmental Alerts and Notifications API Endpoints
Endpoints for alert history, user notification preferences, device token lifecycle,
background evaluation worker, and operational monitoring.
Strict Authentication: Derives user identity strictly from validated JWT/Firebase tokens.
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.core.config import settings
from app.core.security import get_current_authenticated_user, create_access_token
from app.schemas.alert import (
    UserAlertPreferenceInput,
    UserAlertPreferenceResponse,
    DeviceTokenRegisterRequest,
    DeviceTokenUnregisterRequest,
    DeviceTokenRefreshRequest,
    DeviceTokenResponse,
    AlertListResponse,
    AlertItem,
    AlertReadResponse,
    TokenAuthRequest,
    TokenAuthResponse,
    AlertMonitoringStatusResponse,
)
from app.schemas.pollutant import EnvironmentalObservationInput
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.services.alert_service import alert_service
from app.services.alert_worker import alert_worker
from app.services.alert_monitor import alert_monitor
from app.services.fcm_service import fcm_service

router = APIRouter()


@router.post(
    "/auth/token",
    response_model=TokenAuthResponse,
    summary="Issue signed JWT access token for client authentication",
    description="Generates an HMAC-SHA256 Bearer access token for the specified user ID.",
)
async def generate_user_token(payload: TokenAuthRequest) -> TokenAuthResponse:
    """Generate signed JWT token for user authentication and authorization."""
    token = create_access_token(user_id=payload.user_id.strip())
    ttl_seconds = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60
    return TokenAuthResponse(
        access_token=token,
        token_type="bearer",
        user_id=payload.user_id.strip(),
        expires_in_seconds=ttl_seconds,
    )


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
    user_id: str = Depends(get_current_authenticated_user),
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
    user_id: str = Depends(get_current_authenticated_user),
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
    user_id: str = Depends(get_current_authenticated_user),
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
    user_id: str = Depends(get_current_authenticated_user),
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
    user_id: str = Depends(get_current_authenticated_user),
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


@router.post(
    "/device/refresh",
    response_model=DeviceTokenResponse,
    summary="Rotate and refresh FCM device token",
    description="Replaces an old device registration token with a new token for the authenticated user.",
)
async def refresh_device(
    payload: DeviceTokenRefreshRequest,
    user_id: str = Depends(get_current_authenticated_user),
    db: Session = Depends(get_db),
) -> DeviceTokenResponse:
    new_device = alert_service.refresh_device_token(
        db=db,
        user_id=user_id,
        old_token=payload.old_token,
        new_token=payload.new_token,
        device_type=payload.device_type.value,
    )
    return DeviceTokenResponse(
        status="REFRESHED",
        user_id=new_device.user_id,
        token=new_device.token,
        device_type=new_device.device_type,
        is_active=new_device.is_active,
    )


@router.patch(
    "/{alert_id}/read",
    response_model=AlertReadResponse,
    summary="Mark alert as read",
    description="Updates the read status of a specific alert record belonging to the authenticated user.",
)
async def mark_alert_read(
    alert_id: str,
    user_id: str = Depends(get_current_authenticated_user),
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
    description="Evaluates an environmental observation, runs deterministic rules and filters, and triggers alerts for the calling user.",
)
async def evaluate_observation(
    observation: EnvironmentalObservationInput,
    user_id: str = Depends(get_current_authenticated_user),
    db: Session = Depends(get_db),
) -> AlertListResponse:
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


@router.post(
    "/worker/evaluate-all",
    response_model=AlertListResponse,
    summary="Evaluate observation across all subscribers (Worker Ingestion)",
    description="Processes observation against all active user subscriptions with idempotency deduplication.",
)
async def worker_evaluate_all_subscribers(
    observation: EnvironmentalObservationInput,
    user_id: str = Depends(get_current_authenticated_user),
    db: Session = Depends(get_db),
) -> AlertListResponse:
    dispatched = alert_worker.evaluate_observation_for_subscribers(db=db, obs=observation)
    return AlertListResponse(
        alerts=dispatched,
        total=len(dispatched),
        unread_count=len(dispatched),
    )


@router.get(
    "/monitoring/status",
    response_model=AlertMonitoringStatusResponse,
    summary="Operational status and health telemetry",
    description="Reports alert engine operational statistics, evaluation counts, deliveries, invalid tokens, and worker health.",
)
async def get_monitoring_status(
    user_id: str = Depends(get_current_authenticated_user),
) -> AlertMonitoringStatusResponse:
    status_dict = alert_monitor.get_status()
    fcm_mode = "LIVE" if fcm_service.is_live else "MOCK_UNVERIFIED"
    return AlertMonitoringStatusResponse(
        worker_health=status_dict["worker_health"],
        evaluations_total_count=status_dict["evaluations_total_count"],
        alerts_triggered_count=status_dict["alerts_triggered_count"],
        idempotent_skips_count=status_dict["idempotent_skips_count"],
        pending_notifications_count=status_dict["pending_notifications_count"],
        successful_deliveries_count=status_dict["successful_deliveries_count"],
        failed_deliveries_count=status_dict["failed_deliveries_count"],
        invalid_device_tokens_count=status_dict["invalid_device_tokens_count"],
        last_evaluated_station=status_dict["last_evaluated_station"],
        last_evaluation_timestamp=status_dict["last_evaluation_timestamp"],
        last_environmental_data_ingestion=status_dict["last_environmental_data_ingestion"],
        last_error=status_dict["last_error"],
        last_error_timestamp=status_dict["last_error_timestamp"],
        fcm_mode=fcm_mode,
    )
