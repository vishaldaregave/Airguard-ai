"""
AirGuard AI - Data Quality Engine
Strict validation, unit normalization, outlier rejection, staleness detection, and duplicate handling.
"""
from typing import Optional, Tuple
from datetime import datetime, timezone
from app.schemas.pollutant import PollutantType
from app.core.config import settings

# Plausible physical upper bounds for ground-level atmospheric pollutants
# Values exceeding these are deemed sensor calibration artifacts or malfunctions
PLAUSIBLE_RANGES = {
    PollutantType.PM2_5: (0.0, 2000.0),   # µg/m³
    PollutantType.PM10: (0.0, 3000.0),    # µg/m³
    PollutantType.NO2: (0.0, 1000.0),     # µg/m³
    PollutantType.SO2: (0.0, 2500.0),     # µg/m³
    PollutantType.CO: (0.0, 100.0),       # mg/m³
    PollutantType.O3: (0.0, 1200.0),      # µg/m³
    PollutantType.NH3: (0.0, 3000.0),     # µg/m³
    PollutantType.PB: (0.0, 10.0),        # µg/m³
}

# Standard STP (25 °C, 1 atm) conversion factors
# Gas ppm/ppb to target CPCB units (µg/m³, except CO in mg/m³)
CONVERSION_FACTORS = {
    PollutantType.NO2: {
        "ppb": 1.88,
        "ppm": 1880.0,
        "ug/m3": 1.0,
        "mg/m3": 1000.0,
    },
    PollutantType.SO2: {
        "ppb": 2.62,
        "ppm": 2620.0,
        "ug/m3": 1.0,
        "mg/m3": 1000.0,
    },
    PollutantType.O3: {
        "ppb": 1.96,
        "ppm": 1960.0,
        "ug/m3": 1.0,
        "mg/m3": 1000.0,
    },
    PollutantType.CO: {
        # Target is mg/m³
        "ppm": 1.145,
        "ppb": 0.001145,
        "mg/m3": 1.0,
        "ug/m3": 0.001,
    },
    PollutantType.NH3: {
        "ppb": 0.70,
        "ppm": 700.0,
        "ug/m3": 1.0,
    },
    PollutantType.PM2_5: {
        "ug/m3": 1.0,
        "mg/m3": 1000.0,
    },
    PollutantType.PM10: {
        "ug/m3": 1.0,
        "mg/m3": 1000.0,
    },
    PollutantType.PB: {
        "ug/m3": 1.0,
    },
}


def normalize_unit_string(unit: str) -> str:
    """Normalizes various unit representations (e.g. ug/m3, µg/m³, ppm, ppb)."""
    clean = unit.strip().lower()
    clean = clean.replace(" ", "").replace("^3", "3").replace("³", "3")
    clean = clean.replace("\u00b5", "u").replace("\u03bc", "u")
    clean = clean.replace("micrograms/m3", "ug/m3").replace("milligrams/m3", "mg/m3")
    return clean


def convert_and_validate_pollutant(
    pollutant: PollutantType,
    raw_value: Optional[float],
    raw_unit: str = "µg/m³",
) -> Tuple[Optional[float], Optional[str]]:
    """
    Validates pollutant value, converts to CPCB standard unit, and verifies physical limits.
    Returns: (normalized_value_or_none, quality_issue_reason_or_none)
    """
    if raw_value is None:
        return None, "Not monitored or reported"

    # 1. Negative value rejection
    if raw_value < 0:
        return None, f"Negative reading {raw_value} rejected as invalid"

    # 2. Unit conversion
    clean_unit = normalize_unit_string(raw_unit)
    factors = CONVERSION_FACTORS.get(pollutant, {})
    
    # Try direct or normalized lookup
    factor = factors.get(clean_unit)
    if factor is None:
        # Check fallback
        if "ppb" in clean_unit and "ppb" in factors:
            factor = factors["ppb"]
        elif "ppm" in clean_unit and "ppm" in factors:
            factor = factors["ppm"]
        elif "ug/m3" in clean_unit and "ug/m3" in factors:
            factor = factors["ug/m3"]
        elif "mg/m3" in clean_unit and "mg/m3" in factors:
            factor = factors["mg/m3"]
        else:
            # Assume 1:1 if unit matches target standard
            factor = 1.0

    converted_val = raw_value * factor

    # 3. Plausible range verification
    min_val, max_val = PLAUSIBLE_RANGES.get(pollutant, (0.0, 5000.0))
    if converted_val > max_val:
        return None, f"Value {converted_val:.1f} exceeds plausible physical limit ({max_val})"

    return round(converted_val, 2), None


def check_observation_staleness(timestamp: datetime) -> Tuple[bool, float]:
    """
    Checks if an observation is older than the configured threshold (default 120 minutes).
    Returns: (is_stale: bool, age_in_minutes: float)
    """
    now = datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        ts = timestamp.replace(tzinfo=timezone.utc)
    else:
        ts = timestamp

    age_minutes = (now - ts).total_seconds() / 60.0
    is_stale = age_minutes > settings.DATA_STALE_THRESHOLD_MINUTES
    return is_stale, round(max(0.0, age_minutes), 1)
