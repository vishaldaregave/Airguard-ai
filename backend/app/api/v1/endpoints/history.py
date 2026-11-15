"""
AirGuard AI - History Availability and Dataset Audit Endpoints
Audits historical archive depth, completeness by pollutant, and provenance breakdown.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.schemas.history import HistoryAvailabilityResponse
from app.services.history_service import history_service

router = APIRouter()


@router.get(
    "/availability",
    response_model=HistoryAvailabilityResponse,
    summary="Get Historical Dataset Depth, Completeness, and Provenance Breakdown",
    description=(
        "Reports total record count, dataset timespan in days, pollutant completeness percentages, "
        "and strict provenance breakdown across LIVE ground stations, ESTIMATED models, and DEMO fixtures."
    ),
)
async def get_history_availability(
    db: Session = Depends(get_db),
) -> HistoryAvailabilityResponse:
    # Ensure baseline data is seeded if archive is fresh
    history_service.seed_initial_regional_history(db)
    return history_service.get_availability_summary(db)
