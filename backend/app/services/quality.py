"""
AirGuard AI - Data Quality Engine
Scientific validation, temperature/pressure-aware unit normalization, outlier rejection,
staleness detection, coordinate verification, and provenance metadata tracking.
"""
from typing import Any, Dict, Optional, Tuple
from datetime import datetime, timezone
from app.schemas.pollutant import DataSourceType, PollutantType
from app.core.config import settings

# Physical constants
# Universal Gas Constant R = 8.314462618 J/(mol·K) = m³·Pa/(mol·K)
GAS_CONSTANT_R = 8.314462618

# Molar masses of target gases in g/mol
MOLAR_MASSES: Dict[PollutantType, float] = {
    PollutantType.NO2: 46.0055,  # Nitrogen Dioxide
    PollutantType.SO2: 64.0660,  # Sulfur Dioxide
    PollutantType.CO: 28.0101,   # Carbon Monoxide
    PollutantType.O3: 47.9982,   # Ozone
    PollutantType.NH3: 17.0305,  # Ammonia
}

# Standard Reference Conditions (CPCB NAAQS / USEPA Reference State):
# Temperature T_ref = 25.0 °C (298.15 K)
# Pressure P_ref = 1013.25 hPa (101325 Pa = 1 atm)
# Molar volume V_m,ref (L/mol) = (R * 298.15 * 1000) / 101325 = 24.4654 L/mol
#
# Note on scientific terminology:
# Conventional chemical STP is 0 °C (273.15 K) and 1 atm (V_m = 22.414 L/mol).
# Air quality environmental criteria (CPCB and USEPA) explicitly specify conversion
# at Standard Reference Conditions (25 °C and 760 mm Hg / 101.325 kPa), which
# corresponds to SATP (Standard Ambient Temperature and Pressure).
STANDARD_REF_TEMP_K = 298.15        # 25.0 °C
STANDARD_REF_PRESSURE_HPA = 1013.25 # 1013.25 hPa
STANDARD_MOLAR_VOLUME_L = (GAS_CONSTANT_R * STANDARD_REF_TEMP_K * 10.0) / STANDARD_REF_PRESSURE_HPA  # ~24.4654 L/mol

# Plausible physical upper bounds for ground-level atmospheric pollutants
# Values exceeding these are deemed sensor calibration artifacts or malfunctions
PLAUSIBLE_RANGES: Dict[PollutantType, Tuple[float, float]] = {
    PollutantType.PM2_5: (0.0, 2000.0),   # µg/m³
    PollutantType.PM10: (0.0, 3000.0),    # µg/m³
    PollutantType.NO2: (0.0, 1000.0),     # µg/m³
    PollutantType.SO2: (0.0, 2500.0),     # µg/m³
    PollutantType.CO: (0.0, 100.0),       # mg/m³
    PollutantType.O3: (0.0, 1200.0),      # µg/m³
    PollutantType.NH3: (0.0, 3000.0),     # µg/m³
    PollutantType.PB: (0.0, 10.0),        # µg/m³
}

# Standard Reference Condition (25 °C, 1 atm) conversion factors
# Gas ppm/ppb to target CPCB units (µg/m³, except CO in mg/m³)
# Derived deterministically from M / V_m,ref:
# NO2: 46.0055 / 24.4654 = 1.88 µg/m³ per ppb
# SO2: 64.0660 / 24.4654 = 2.62 µg/m³ per ppb
# O3:  47.9982 / 24.4654 = 1.96 µg/m³ per ppb
# CO:  28.0101 / 24.4654 = 1.145 mg/m³ per ppm (0.001145 mg/m³ per ppb)
# NH3: 17.0305 / 24.4654 = 0.70 µg/m³ per ppb
STANDARD_REFERENCE_FACTORS = {
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
        "mg/m3": 1000.0,
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
        "mg/m3": 1000.0,
    },
}

# Backward compatibility alias
CONVERSION_FACTORS = STANDARD_REFERENCE_FACTORS

# Provider-specific freshness thresholds (in minutes)
# CPCB ground stations publish hourly averages; Open-Meteo updates hourly; OpenAQ v3 varies by station.
PROVIDER_STALENESS_THRESHOLDS_MINUTES: Dict[str, float] = {
    "openaq": 120.0,
    "open_meteo": 90.0,
    "open-meteo": 90.0,
    "cpcb": 180.0,
    "cpcb_datagov": 180.0,
    "demo_fixtures": 120.0,
}


def normalize_unit_string(unit: str) -> str:
    """Normalizes various unit representations (e.g. ug/m3, µg/m³, ppm, ppb)."""
    clean = unit.strip().lower()
    clean = clean.replace(" ", "").replace("^3", "3").replace("³", "3")
    clean = clean.replace("\u00b5", "u").replace("\u03bc", "u")
    clean = clean.replace("micrograms/m3", "ug/m3").replace("milligrams/m3", "mg/m3")
    return clean


def compute_gas_conversion_factor(
    pollutant: PollutantType,
    unit: str,
    temperature_celsius: Optional[float] = None,
    pressure_hpa: Optional[float] = None,
) -> Tuple[float, str]:
    """
    Computes gas conversion factor dynamically if temperature and pressure are available,
    or falls back to CPCB / EPA Standard Reference Conditions (25 °C, 1013.25 hPa).

    Formula:
        V_m (L/mol) = (R * T_K * 10) / P_hpa
        Factor (ppb -> µg/m³) = M / V_m
        For CO (ppb -> mg/m³): (M / V_m) * 1e-3, (ppm -> mg/m³): M / V_m

    Returns:
        (factor, reference_condition_description)
    """
    clean_unit = normalize_unit_string(unit)
    is_ppm = "ppm" in clean_unit
    is_ppb = "ppb" in clean_unit

    if not is_ppm and not is_ppb:
        # Mass per volume unit: direct standard conversion
        std_factors = STANDARD_REFERENCE_FACTORS.get(pollutant, {})
        factor = std_factors.get(clean_unit, 1.0)
        return factor, "Direct mass concentration (no gas law conversion needed)"

    # Gas mixing ratio conversion (ppb / ppm)
    molar_mass = MOLAR_MASSES.get(pollutant)
    if molar_mass is None:
        return 1.0, "Unit assumed 1:1"

    if temperature_celsius is not None:
        temp_k = temperature_celsius + 273.15
        p_hpa = pressure_hpa if pressure_hpa is not None else STANDARD_REF_PRESSURE_HPA
        molar_vol_l = (GAS_CONSTANT_R * temp_k * 10.0) / p_hpa
        ref_desc = f"Ambient conditions adjusted (T={temperature_celsius:.1f} °C, P={p_hpa:.1f} hPa)"
    else:
        # CPCB Standard Reference Conditions (25 °C, 1013.25 hPa)
        molar_vol_l = STANDARD_MOLAR_VOLUME_L
        ref_desc = "Standard Reference Conditions (25.0 °C, 1013.25 hPa / 1 atm, CPCB NAAQS Reference)"

    # For CO, target unit is mg/m³
    if pollutant == PollutantType.CO:
        # 1 ppm CO = M / V_m mg/m³
        factor_ppm = molar_mass / molar_vol_l
        factor_ppb = factor_ppm * 1e-3
    else:
        # Target unit is µg/m³
        # 1 ppb Gas = M / V_m µg/m³
        factor_ppb = molar_mass / molar_vol_l
        factor_ppm = factor_ppb * 1e3

    factor = factor_ppm if is_ppm else factor_ppb
    return factor, ref_desc


def convert_and_validate_pollutant(
    pollutant: PollutantType,
    raw_value: Optional[float],
    raw_unit: str = "µg/m³",
    temperature_celsius: Optional[float] = None,
    pressure_hpa: Optional[float] = None,
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

    # 2. Temperature/pressure-aware unit conversion
    clean_unit = normalize_unit_string(raw_unit)
    if "ppb" in clean_unit or "ppm" in clean_unit:
        factor, _ = compute_gas_conversion_factor(
            pollutant, raw_unit, temperature_celsius, pressure_hpa
        )
    else:
        factors = STANDARD_REFERENCE_FACTORS.get(pollutant, {})
        factor = factors.get(clean_unit)
        if factor is None:
            if "ug/m3" in clean_unit and "ug/m3" in factors:
                factor = factors["ug/m3"]
            elif "mg/m3" in clean_unit and "mg/m3" in factors:
                factor = factors["mg/m3"]
            else:
                factor = 1.0

    converted_val = raw_value * factor

    # 3. Plausible range verification
    min_val, max_val = PLAUSIBLE_RANGES.get(pollutant, (0.0, 5000.0))
    if converted_val > max_val:
        return None, f"Value {converted_val:.1f} exceeds plausible physical limit ({max_val})"

    return round(converted_val, 2), None


def convert_and_validate_with_metadata(
    pollutant: PollutantType,
    raw_value: Optional[float],
    raw_unit: str = "µg/m³",
    temperature_celsius: Optional[float] = None,
    pressure_hpa: Optional[float] = None,
) -> Tuple[Optional[float], Optional[str], Dict[str, Any]]:
    """
    Enhanced version of convert_and_validate_pollutant that also returns scientific conversion metadata.
    Preserves raw unit, target unit, factor used, and reference conditions.
    """
    target_unit = "mg/m³" if pollutant == PollutantType.CO else "µg/m³"
    clean_unit = normalize_unit_string(raw_unit)

    if "ppb" in clean_unit or "ppm" in clean_unit:
        factor, ref_desc = compute_gas_conversion_factor(
            pollutant, raw_unit, temperature_celsius, pressure_hpa
        )
    else:
        factors = STANDARD_REFERENCE_FACTORS.get(pollutant, {})
        factor = factors.get(clean_unit, 1.0)
        ref_desc = "Direct mass-concentration units"

    val, reason = convert_and_validate_pollutant(
        pollutant, raw_value, raw_unit, temperature_celsius, pressure_hpa
    )

    metadata = {
        "pollutant": pollutant.value,
        "raw_value": raw_value,
        "raw_unit": raw_unit,
        "normalized_value": val,
        "normalized_unit": target_unit,
        "conversion_factor": round(factor, 5),
        "reference_condition": ref_desc,
        "validation_status": "VALID" if val is not None else "REJECTED",
        "rejection_reason": reason,
    }
    return val, reason, metadata


def check_observation_staleness(
    timestamp: datetime,
    provider_name: Optional[str] = None,
    data_source_type: Optional[DataSourceType] = None,
) -> Tuple[bool, float]:
    """
    Checks if an observation is older than provider-specific threshold or in the future.
    Handles distinct thresholds for ground stations (OpenAQ, CPCB) vs atmospheric models (Open-Meteo).
    Returns: (is_stale: bool, age_in_minutes: float)
    """
    now = datetime.now(timezone.utc)
    if timestamp.tzinfo is None:
        ts = timestamp.replace(tzinfo=timezone.utc)
    else:
        ts = timestamp

    age_minutes = (now - ts).total_seconds() / 60.0

    # Determine threshold
    threshold = settings.DATA_STALE_THRESHOLD_MINUTES
    if provider_name:
        clean_p = provider_name.lower().replace("-", "_").replace(" ", "_")
        for p_key, p_thresh in PROVIDER_STALENESS_THRESHOLDS_MINUTES.items():
            clean_k = p_key.lower().replace("-", "_").replace(" ", "_")
            if clean_k in clean_p or clean_p in clean_k:
                threshold = p_thresh
                break

    # If timestamp is in the future (>5 minutes ahead)
    # Valid only if data_source_type is explicitly FORECAST
    if age_minutes < -5.0:
        if data_source_type == DataSourceType.FORECAST:
            return False, round(age_minutes, 1)
        # Clock anomaly or future timestamp in live/estimated data: flag as stale/anomaly
        return True, round(age_minutes, 1)

    is_stale = age_minutes > threshold
    return is_stale, round(max(0.0, age_minutes), 1)


def validate_station_coordinates(latitude: Optional[float], longitude: Optional[float]) -> Tuple[bool, Optional[str]]:
    """
    Validates geographic coordinates for monitoring stations.
    Rejects Null Island (0,0) and out-of-bounds latitude/longitude.
    """
    if latitude is None or longitude is None:
        return False, "Coordinates cannot be None"
    if not (-90.0 <= latitude <= 90.0):
        return False, f"Latitude {latitude} out of valid range [-90, 90]"
    if not (-180.0 <= longitude <= 180.0):
        return False, f"Longitude {longitude} out of valid range [-180, 180]"
    if abs(latitude) < 0.0001 and abs(longitude) < 0.0001:
        return False, "Null Island (0, 0) coordinates rejected as uncalibrated GPS"
    return True, None
