"""
AirGuard AI - Air Quality Observation & Status Endpoints
Pure HTTP GET semantics for retrieval; explicit POST endpoint for telemetry ingestion.
"""
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.schemas.pollutant import EnvironmentalObservationInput
from app.schemas.provider import (
    AirQualityHistoryResponse,
    CurrentAirQualityResponse,
    ProviderStatusResponse,
    AirQualityIngestResponse,
)
from app.services.environmental_service import environmental_service
from app.services.alert_worker import alert_worker

router = APIRouter()


@router.get(
    "/current",
    response_model=CurrentAirQualityResponse,
    summary="Get Current Air Quality, CPCB AQI, and Risk Assessment",
    description=(
        "Retrieves current air quality for either a specific station_id or GPS coordinates. "
        "Returns normalized pollutant measurements, CPCB IND-AQI calculation, explainable exposure risk, "
        "and data freshness/provenance indicators. Safe and side-effect free: does not dispatch alerts."
    ),
)
async def get_current_air(
    station_id: Optional[str] = Query(None, description="Station identifier (e.g. OPENAQ-1234, DEMO-DELHI-001)"),
    lat: Optional[float] = Query(None, ge=-90.0, le=90.0, description="User latitude"),
    lon: Optional[float] = Query(None, ge=-180.0, le=180.0, description="User longitude"),
) -> CurrentAirQualityResponse:
    """
    HTTP GET is safe and idempotent.
    Retrieves air quality data without side effects or alert notification dispatches.
    """
    if not station_id and (lat is None or lon is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either 'station_id' or both 'lat' and 'lon' coordinates must be provided.",
        )

    res = await environmental_service.get_current_air_quality(
        station_id=station_id, latitude=lat, longitude=lon
    )
    if not res:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Environmental observation not available for the requested location or station.",
        )

    return res


@router.post(
    "/ingest",
    response_model=AirQualityIngestResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Ingest Environmental Observation & Queue Durable Alert Evaluation",
    description=(
        "Ingests verified environmental telemetry from monitoring agencies or sensors. "
        "Enqueues a durable background evaluation job that survives server restarts, "
        "prevents duplicate notification dispatch, and enforces subscriber preferences."
    ),
)
async def ingest_environmental_observation(
    observation: EnvironmentalObservationInput,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> AirQualityIngestResponse:
    """
    Explicit telemetry ingestion endpoint.
    Separates data write/event flows from read-only data retrieval (RFC 7231 / RFC 9110 compliance).
    Enqueues a durable evaluation job that survives server restarts.
    """
    # 1. Enqueue durable job in database
    job = alert_worker.enqueue_observation_job(db=db, obs=observation)

    # 2. Trigger worker processing asynchronously (non-blocking, worker will pick up from DB)
    background_tasks.add_task(alert_worker.process_job_by_id, job.job_id)

    return AirQualityIngestResponse(
        status="QUEUED" if job.status == "PENDING" else job.status,
        job_id=job.job_id,
        eval_hash=job.eval_hash,
        station_code=job.station_code,
        observation_timestamp=job.observation_timestamp,
        is_correction=getattr(observation, "is_correction", False),
        revision=getattr(observation, "revision", 0),
        message=f"Observation ingested with job status '{job.status}' (attempts: {job.attempts})",
    )


@router.get(
    "/history",
    response_model=AirQualityHistoryResponse,
    summary="Get Historical Air Quality Observations for a Station",
    description="Returns chronological time series of normalized observations up to the requested hours.",
)
async def get_air_history(
    station_id: str = Query(..., description="Station identifier"),
    hours: int = Query(24, ge=1, le=168, description="Number of historical hours to retrieve"),
) -> AirQualityHistoryResponse:
    observations = await environmental_service.get_air_history(station_id, hours)
    station = await environmental_service.get_station_by_id(station_id)

    return AirQualityHistoryResponse(
        station_id=station_id,
        station_name=station.station_name if station else station_id,
        provider=station.provider if station else "Environmental Provider",
        data_source_type=station.data_source_type if station else "HISTORICAL",
        count=len(observations),
        observations=observations,
    )


@router.get(
    "/providers/status",
    response_model=ProviderStatusResponse,
    summary="Get Health and Connectivity Status of All Configured Providers",
    description=(
        "Reports live status (ONLINE, DEGRADED, UNAUTHENTICATED, OFFLINE), authentication, "
        "latency, supported pollutants, and legal attribution for each data provider."
    ),
)
async def get_providers_status() -> ProviderStatusResponse:
    return await environmental_service.get_providers_status()
