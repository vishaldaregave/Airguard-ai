"""
AirGuard AI - Pure Deterministic CPCB National AQI Engine
Implements Central Pollution Control Board (CPCB) India methodology.
Zero hallucinations. Pure deterministic mathematics.
"""
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from app.schemas.pollutant import EnvironmentalObservationInput, PollutantType
from app.schemas.aqi import (
    AQICalculationResult,
    AQICategory,
    AQIColorCode,
    CalculationStatus,
    HealthAdvisory,
    SubIndexResult,
)
from app.services.quality import check_observation_staleness


# Official CPCB Continuous Breakpoints: (B_lo, B_hi, I_lo, I_hi)
# Piecewise continuous linear interpolation across health impact classes:
# Good (0-50), Satisfactory (50-100), Moderate (100-200), Poor (200-300), Very Poor (300-400), Severe (400-500)
CPCB_BREAKPOINTS: Dict[PollutantType, List[Tuple[float, float, int, int]]] = {
    PollutantType.PM10: [
        (0.0, 50.0, 0, 50),
        (50.0, 100.0, 50, 100),
        (100.0, 250.0, 100, 200),
        (250.0, 350.0, 200, 300),
        (350.0, 430.0, 300, 400),
        (430.0, 500.0, 400, 500),
    ],
    PollutantType.PM2_5: [
        (0.0, 30.0, 0, 50),
        (30.0, 60.0, 50, 100),
        (60.0, 90.0, 100, 200),
        (90.0, 120.0, 200, 300),
        (120.0, 250.0, 300, 400),
        (250.0, 350.0, 400, 500),
    ],
    PollutantType.NO2: [
        (0.0, 40.0, 0, 50),
        (40.0, 80.0, 50, 100),
        (80.0, 180.0, 100, 200),
        (180.0, 280.0, 200, 300),
        (280.0, 400.0, 300, 400),
        (400.0, 500.0, 400, 500),
    ],
    PollutantType.O3: [
        (0.0, 50.0, 0, 50),
        (50.0, 100.0, 50, 100),
        (100.0, 168.0, 100, 200),
        (168.0, 208.0, 200, 300),
        (208.0, 748.0, 300, 400),
        (748.0, 1000.0, 400, 500),
    ],
    PollutantType.CO: [
        (0.0, 1.0, 0, 50),
        (1.0, 2.0, 50, 100),
        (2.0, 10.0, 100, 200),
        (10.0, 17.0, 200, 300),
        (17.0, 34.0, 300, 400),
        (34.0, 50.0, 400, 500),
    ],
    PollutantType.SO2: [
        (0.0, 40.0, 0, 50),
        (40.0, 80.0, 50, 100),
        (80.0, 380.0, 100, 200),
        (380.0, 800.0, 200, 300),
        (800.0, 1600.0, 300, 400),
        (1600.0, 2000.0, 400, 500),
    ],
    PollutantType.NH3: [
        (0.0, 200.0, 0, 50),
        (200.0, 400.0, 50, 100),
        (400.0, 800.0, 100, 200),
        (800.0, 1200.0, 200, 300),
        (1200.0, 1800.0, 300, 400),
        (1800.0, 2400.0, 400, 500),
    ],
    PollutantType.PB: [
        (0.0, 0.5, 0, 50),
        (0.5, 1.0, 50, 100),
        (1.0, 2.0, 100, 200),
        (2.0, 3.0, 200, 300),
        (3.0, 3.5, 300, 400),
        (3.5, 5.0, 400, 500),
    ],
}

POLLUTANT_UNITS = {
    PollutantType.PM10: "µg/m³",
    PollutantType.PM2_5: "µg/m³",
    PollutantType.NO2: "µg/m³",
    PollutantType.O3: "µg/m³",
    PollutantType.CO: "mg/m³",
    PollutantType.SO2: "µg/m³",
    PollutantType.NH3: "µg/m³",
    PollutantType.PB: "µg/m³",
}

# CPCB Reference Averaging Periods:
# PM10, PM2.5, NO2, SO2, NH3, Pb: 24-hour average
# CO, O3: 8-hour average (or 1-hour sub-index during severe events)
CPCB_AVERAGING_PERIODS: Dict[PollutantType, int] = {
    PollutantType.PM10: 24,
    PollutantType.PM2_5: 24,
    PollutantType.NO2: 24,
    PollutantType.SO2: 24,
    PollutantType.NH3: 24,
    PollutantType.PB: 24,
    PollutantType.CO: 8,
    PollutantType.O3: 8,
}


def get_aqi_category(aqi_val: int) -> AQICategory:
    """Return CPCB AQI Category for a given index value."""
    if aqi_val <= 50:
        return AQICategory.GOOD
    elif aqi_val <= 100:
        return AQICategory.SATISFACTORY
    elif aqi_val <= 200:
        return AQICategory.MODERATE
    elif aqi_val <= 300:
        return AQICategory.POOR
    elif aqi_val <= 400:
        return AQICategory.VERY_POOR
    else:
        return AQICategory.SEVERE


def get_color_code(category: AQICategory) -> str:
    """Return hex color code associated with AQI Category."""
    mapping = {
        AQICategory.GOOD: AQIColorCode.GOOD.value,
        AQICategory.SATISFACTORY: AQIColorCode.SATISFACTORY.value,
        AQICategory.MODERATE: AQIColorCode.MODERATE.value,
        AQICategory.POOR: AQIColorCode.POOR.value,
        AQICategory.VERY_POOR: AQIColorCode.VERY_POOR.value,
        AQICategory.SEVERE: AQIColorCode.SEVERE.value,
    }
    return mapping.get(category, AQIColorCode.MODERATE.value)


def calculate_sub_index(
    pollutant: PollutantType, concentration: float
) -> Optional[SubIndexResult]:
    """
    Calculates sub-index Ip for a given pollutant using CPCB piecewise linear interpolation:
    Ip = [(I_hi - I_lo) / (B_hi - B_lo)] * (Cp - B_lo) + I_lo
    """
    if concentration is None or concentration < 0:
        return None

    breakpoints = CPCB_BREAKPOINTS.get(pollutant)
    if not breakpoints:
        return None

    # Handle value below lowest breakpoint
    if concentration <= breakpoints[0][0]:
        b_lo, b_hi, i_lo, i_hi = breakpoints[0]
        return SubIndexResult(
            pollutant=pollutant.value,
            concentration=concentration,
            unit=POLLUTANT_UNITS[pollutant],
            sub_index=0,
            category=AQICategory.GOOD,
            breakpoint_low=b_lo,
            breakpoint_high=b_hi,
            index_low=i_lo,
            index_high=i_hi,
            averaging_period_hours=CPCB_AVERAGING_PERIODS.get(pollutant),
        )

    matched_bp = None
    for b_lo, b_hi, i_lo, i_hi in breakpoints:
        if b_lo <= concentration <= b_hi:
            matched_bp = (b_lo, b_hi, i_lo, i_hi)
            break

    # If concentration exceeds highest defined breakpoint, cap at 500
    if not matched_bp:
        highest_bp = breakpoints[-1]
        if concentration > highest_bp[1]:
            matched_bp = (highest_bp[1], concentration, 500, 500)
            sub_index = 500
        else:
            # Fallback for floating numerical edge
            matched_bp = breakpoints[-1]

    b_lo, b_hi, i_lo, i_hi = matched_bp
    if b_hi == b_lo:
        sub_index = i_hi
    else:
        # CPCB Official Linear Interpolation formula
        raw_index = ((i_hi - i_lo) / (b_hi - b_lo)) * (concentration - b_lo) + i_lo
        # Half-up rounding (CPCB standard mathematical convention)
        sub_index = int(raw_index + 0.5)
        # Ensure within bounds [0, 500]
        sub_index = max(0, min(500, sub_index))

    category = get_aqi_category(sub_index)
    return SubIndexResult(
        pollutant=pollutant.value,
        concentration=concentration,
        unit=POLLUTANT_UNITS[pollutant],
        sub_index=sub_index,
        category=category,
        breakpoint_low=b_lo,
        breakpoint_high=b_hi,
        index_low=i_lo,
        index_high=i_hi,
        averaging_period_hours=CPCB_AVERAGING_PERIODS.get(pollutant),
    )


def get_grounded_health_advisory(category: AQICategory) -> HealthAdvisory:
    """Official grounded CPCB statements without medical claims."""
    if category == AQICategory.GOOD:
        return HealthAdvisory(
            category=category,
            general_statement="Minimal health impact. Air quality is considered satisfactory, and air pollution poses little or no risk.",
            sensitive_group_advice="No specific precautions needed. Safe for all demographic groups.",
            outdoor_activity_advice="Ideal conditions for outdoor exercise, jogging, sports, and ventilation.",
            recommended_mask=None,
            air_purifier_advice="Natural ventilation recommended.",
        )
    elif category == AQICategory.SATISFACTORY:
        return HealthAdvisory(
            category=category,
            general_statement="Minor breathing discomfort to sensitive people.",
            sensitive_group_advice="Individuals with respiratory conditions (asthma) should monitor symptoms during prolonged physical exertion.",
            outdoor_activity_advice="Safe for normal outdoor activities. Unusually sensitive individuals should consider taking breaks.",
            recommended_mask=None,
            air_purifier_advice="Ventilation is acceptable during low traffic hours.",
        )
    elif category == AQICategory.MODERATE:
        return HealthAdvisory(
            category=category,
            general_statement="Breathing discomfort to people with lungs, asthma and heart diseases.",
            sensitive_group_advice="People with lung disease, older adults and children should reduce prolonged or heavy outdoor exertion.",
            outdoor_activity_advice="Moderate outdoor exercise is acceptable; avoid strenuous exertion during peak traffic hours.",
            recommended_mask="Consider a well-fitting particulate mask (N95/FFP2) if symptomatic.",
            air_purifier_advice="Run indoor air filtration in bedrooms during nighttime.",
        )
    elif category == AQICategory.POOR:
        return HealthAdvisory(
            category=category,
            general_statement="Breathing discomfort to most people on prolonged exposure.",
            sensitive_group_advice="People with lung or heart disease, children and older adults should avoid prolonged outdoor exertion.",
            outdoor_activity_advice="Reduce intense outdoor physical activities. Shift workouts to indoor spaces.",
            recommended_mask="N95 / FFP2 particulate respirator recommended for extended outdoor presence.",
            air_purifier_advice="Keep windows closed. Use HEPA air purification indoors.",
        )
    elif category == AQICategory.VERY_POOR:
        return HealthAdvisory(
            category=category,
            general_statement="Respiratory illness to the people on prolonged exposure. Effect may be more pronounced in people with lung and heart diseases.",
            sensitive_group_advice="Vulnerable populations must avoid all outdoor physical activity and remain indoors in filtered environments.",
            outdoor_activity_advice="Avoid all outdoor exercise. Everyone should significantly limit outdoor exertion.",
            recommended_mask="Certified N95 / N99 mask strongly advised whenever stepping outdoors.",
            air_purifier_advice="Keep doors and windows sealed. Operate HEPA air purifiers continuously.",
        )
    else:  # SEVERE
        return HealthAdvisory(
            category=category,
            general_statement="Respiratory effects even on healthy people and serious health impacts on people with lung/heart diseases. The health impacts may be experienced even during light physical activity.",
            sensitive_group_advice="Absolute restriction of outdoor exposure. Stay inside sealed, air-purified rooms.",
            outdoor_activity_advice="Avoid all outdoor activities entirely. Do not exercise outdoors.",
            recommended_mask="N95 / N99 respirator mandatory for unavoidable outdoor transitions.",
            air_purifier_advice="Continuous high-efficiency particulate filtration essential. Create a clean room environment indoors.",
        )


def calculate_cpcb_aqi(obs: EnvironmentalObservationInput) -> AQICalculationResult:
    """
    CPCB National AQI Calculation Engine:
    1. Evaluates sub-indices for monitored pollutants using piecewise linear interpolation.
    2. Enforces CPCB criteria:
       - At least 3 monitored pollutants required.
       - At least one MUST be PM2.5 or PM10.
    3. If valid:
       - Overall AQI = max(sub_indices).
       - Prominent pollutant = pollutant with max sub-index.
    4. Evaluates data freshness using provider-specific threshold.
    """
    now = datetime.now(timezone.utc)

    # Staleness check with provider-specific threshold
    is_stale, _ = check_observation_staleness(
        obs.timestamp, provider_name=obs.provider, data_source_type=obs.data_source_type
    )

    # Gather available concentrations
    candidate_pollutants: Dict[PollutantType, Optional[float]] = {
        PollutantType.PM2_5: obs.pm2_5,
        PollutantType.PM10: obs.pm10,
        PollutantType.NO2: obs.no2,
        PollutantType.SO2: obs.so2,
        PollutantType.CO: obs.co,
        PollutantType.O3: obs.o3,
        PollutantType.NH3: obs.nh3,
        PollutantType.PB: obs.pb,
    }

    sub_indices: Dict[str, SubIndexResult] = {}
    has_pm25 = False
    has_pm10 = False

    for p_type, concentration in candidate_pollutants.items():
        if concentration is not None:
            sub_res = calculate_sub_index(p_type, concentration)
            if sub_res is not None:
                sub_indices[p_type.value] = sub_res
                if p_type == PollutantType.PM2_5:
                    has_pm25 = True
                elif p_type == PollutantType.PM10:
                    has_pm10 = True

    monitored_count = len(sub_indices)
    has_particulate = has_pm25 or has_pm10

    # CPCB Rule Check:
    # Requires at least 3 pollutants with at least one PM (PM2.5 or PM10)
    if monitored_count < 3 or not has_particulate:
        reason_parts = []
        if monitored_count < 3:
            reason_parts.append(
                f"CPCB criteria requires at least 3 monitored pollutants, but only {monitored_count} provided."
            )
        if not has_particulate:
            reason_parts.append(
                "CPCB criteria requires at least one particulate matter measurement (PM2.5 or PM10)."
            )

        status_msg = " ".join(reason_parts)
        return AQICalculationResult(
            standard="CPCB_INDIA",
            status=CalculationStatus.INSUFFICIENT_POLLUTANTS,
            status_message=status_msg,
            overall_aqi=None,
            category=None,
            color_code=None,
            prominent_pollutant=None,
            sub_indices=sub_indices,
            monitored_pollutant_count=monitored_count,
            has_particulate_matter=has_particulate,
            health_advisory=None,
            is_stale=is_stale,
            data_source_type=obs.data_source_type,
            provider=obs.provider,
            observation_timestamp=obs.timestamp,
            calculation_timestamp=now,
            location=obs.location,
        )

    # Calculate overall AQI: Max of all valid sub-indices
    # Sort by sub_index descending. If tied, PM2.5 / PM10 preferred
    sorted_sub_indices = sorted(
        sub_indices.values(),
        key=lambda item: (item.sub_index, item.pollutant in ["PM2.5", "PM10"]),
        reverse=True,
    )

    max_item = sorted_sub_indices[0]
    overall_aqi = max_item.sub_index
    prominent_pollutant = max_item.pollutant
    overall_category = get_aqi_category(overall_aqi)
    color_code = get_color_code(overall_category)
    health_advisory = get_grounded_health_advisory(overall_category)

    status = CalculationStatus.STALE_DATA if is_stale else CalculationStatus.VALID
    status_msg = (
        "Observation data is stale (exceeds freshness threshold), but AQI calculation is deterministic."
        if is_stale
        else "AQI successfully computed under CPCB National AQI guidelines."
    )

    return AQICalculationResult(
        standard="CPCB_INDIA",
        status=status,
        status_message=status_msg,
        overall_aqi=overall_aqi,
        category=overall_category,
        color_code=color_code,
        prominent_pollutant=prominent_pollutant,
        sub_indices=sub_indices,
        monitored_pollutant_count=monitored_count,
        has_particulate_matter=has_particulate,
        health_advisory=health_advisory,
        is_stale=is_stale,
        data_source_type=obs.data_source_type,
        provider=obs.provider,
        observation_timestamp=obs.timestamp,
        calculation_timestamp=now,
        location=obs.location,
    )
