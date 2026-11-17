"""
AirGuard AI - Historical Data & Environmental Analytics Endpoints
Milestone 5.4: Evidence-driven environmental history, trends, calendar, extremes,
location comparisons, coverage audits, report generation, and explainable insights.
"""
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.schemas.history import (
    HistoricalCalendarResponse,
    HistoricalCompareRequest,
    HistoricalCompareResponse,
    HistoricalCoverageResponse,
    HistoricalExplanationRequest,
    HistoricalExplanationResponse,
    HistoricalExtremesResponse,
    HistoricalPollutantsResponse,
    HistoricalReportResponse,
    HistoricalSummaryResponse,
    HistoricalTrendsResponse,
    HistoryAvailabilityResponse,
)
from app.services.history_service import history_service

router = APIRouter()


# =========================================================================
# 1. DATASET AVAILABILITY AUDIT (MILESTONE 3.1 & 3.2 PRESERVED)
# =========================================================================

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
    history_service.seed_initial_regional_history(db)
    return history_service.get_availability_summary(db)


# =========================================================================
# 2. HISTORICAL SUMMARY
# =========================================================================

@router.get(
    "/summary",
    response_model=HistoricalSummaryResponse,
    summary="Historical Air Quality Summary and Statistical Metrics",
    description=(
        "Provides comprehensive descriptive statistics (mean, median, min, max, std, category distribution) "
        "and overall trend for a monitoring station over a configurable period (24h, 7d, 30d, 90d, 1y)."
    ),
)
async def get_historical_summary(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("7d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalSummaryResponse:
    return history_service.get_history_summary(db, station_code=station_id, period=period)


# =========================================================================
# 3. HISTORICAL TRENDS & TIME SERIES
# =========================================================================

@router.get(
    "/trends",
    response_model=HistoricalTrendsResponse,
    summary="Historical Trend Evaluation and Diurnal Profile",
    description=(
        "Evaluates linear slope per day, R² fit, statistical significance, and generates "
        "chronological time points with data gaps demarcated, along with a 24-hour diurnal profile."
    ),
)
async def get_historical_trends(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("7d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    interval: str = Query("auto", description="Aggregation interval: auto, hourly, 6-hourly, daily"),
    db: Session = Depends(get_db),
) -> HistoricalTrendsResponse:
    return history_service.get_history_trends(db, station_code=station_id, period=period, interval=interval)


# =========================================================================
# 4. POLLUTANTS BREAKDOWN
# =========================================================================

@router.get(
    "/pollutants",
    response_model=HistoricalPollutantsResponse,
    summary="Criteria Pollutants Breakdown and Standard Exceedances",
    description=(
        "Provides statistical metrics, slope, and regulatory limit exceedance rates for "
        "all criteria pollutants (PM2.5, PM10, NO2, SO2, CO, O3) over the selected period."
    ),
)
async def get_historical_pollutants(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("7d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalPollutantsResponse:
    return history_service.get_history_pollutants(db, station_code=station_id, period=period)


# =========================================================================
# 5. PEAK & CLEANEST EXTREMES
# =========================================================================

@router.get(
    "/extremes",
    response_model=HistoricalExtremesResponse,
    summary="Elevated Pollution Episodes and Clean Air Windows",
    description=(
        "Detects sustained peak pollution episodes (AQI >= 200) and favorable dispersion windows (AQI <= 100) "
        "with co-occurring temperature, wind speed, and duration context."
    ),
)
async def get_historical_extremes(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("7d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalExtremesResponse:
    return history_service.get_history_extremes(db, station_code=station_id, period=period)


# =========================================================================
# 6. DAILY POLLUTION CALENDAR
# =========================================================================

@router.get(
    "/calendar",
    response_model=HistoricalCalendarResponse,
    summary="Daily Historical Pollution Calendar View",
    description=(
        "Calendar-style daily aggregated air-quality categories enforcing the statutory CPCB "
        "16-Hour minimum rule for valid daily AQI. Marks unavailable and insufficient days distinctly."
    ),
)
async def get_historical_calendar(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("30d", description="Analysis period: 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalCalendarResponse:
    return history_service.get_history_calendar(db, station_code=station_id, period=period)


# =========================================================================
# 7. LOCATION COMPARISON
# =========================================================================

@router.post(
    "/compare",
    response_model=HistoricalCompareResponse,
    summary="Historical Comparison Between Two Monitoring Locations",
    description=(
        "Compares two physical stations, or a physical monitor vs a model grid, showing "
        "AQI deltas, pollutant differences, coverage discrepancies, and explicit provenance caveats."
    ),
)
async def compare_historical_locations_endpoint(
    request: HistoricalCompareRequest,
    db: Session = Depends(get_db),
) -> HistoricalCompareResponse:
    return history_service.compare_history_locations(db, request=request)


# =========================================================================
# 8. DATA COVERAGE & GAP AUDIT
# =========================================================================

@router.get(
    "/coverage",
    response_model=HistoricalCoverageResponse,
    summary="Audit Historical Observation Coverage and Missing Intervals",
    description=(
        "Audits empirical observation completeness, expected vs actual sample counts, "
        "detected data gap intervals (>2h), longest gap, and temporal regularity score."
    ),
)
async def get_historical_coverage(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("30d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalCoverageResponse:
    return history_service.get_history_coverage(db, station_code=station_id, period=period)


# =========================================================================
# 9. REPORT GENERATION & EXPORT
# =========================================================================

@router.get(
    "/report",
    response_model=HistoricalReportResponse,
    summary="Generate Comprehensive Historical Environmental Intelligence Report",
    description=(
        "Compiles an exhaustive, publication-grade environmental report in structured JSON "
        "and formatted Markdown, ready for export and archival."
    ),
)
async def get_historical_report(
    station_id: str = Query(..., description="Monitoring station code or model grid ID"),
    period: str = Query("7d", description="Analysis period: 24h, 7d, 30d, 90d, 1y"),
    db: Session = Depends(get_db),
) -> HistoricalReportResponse:
    return history_service.generate_history_report(db, station_code=station_id, period=period)


# =========================================================================
# 10. AI EVIDENCE-BASED EXPLANATION
# =========================================================================

@router.post(
    "/explain",
    response_model=HistoricalExplanationResponse,
    summary="Explain Historical Trends and Diurnal Observations",
    description=(
        "Provides objective scientific explanations of observed trends, diurnal peaks, "
        "and coverage limitations without making unsupported causal claims or clinical diagnoses."
    ),
)
async def explain_historical_analytics(
    request: HistoricalExplanationRequest,
) -> HistoricalExplanationResponse:
    return history_service.explain_history(request)
