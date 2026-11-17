"""
AirGuard AI - Exposure Calculation Engine
Pure modular, deterministic, independently testable environmental pollutant exposure engine.
Calculates cumulative concentration-time exposure and estimated gross inhaled pollutant mass
based on authoritative respiratory physiology data (US EPA Exposure Factors Handbook).
"""
from typing import Dict, List, Optional, Tuple
from app.schemas.exposure import (
    ActivityProfile,
    ActivityType,
    ExposureSimulationResponse,
    PollutantComparisonDelta,
    PollutantExposureMetric,
)

# Standard Activity Profiles based on US EPA Exposure Factors Handbook (2011 Edition, Chapter 6: Inhalation Rates)
ACTIVITY_PROFILES: Dict[ActivityType, ActivityProfile] = {
    ActivityType.RESTING: ActivityProfile(
        activity_type=ActivityType.RESTING,
        display_name="Resting / Sedentary",
        inhalation_rate_m3_h=0.50,
        met_equivalent=1.0,
        description="Quiet rest, sleep, or sedentary desk work with basal ventilation (~8.3 L/min).",
        reference="US EPA Exposure Factors Handbook (2011 Edition, Table 6-2: Sedentary/Passive; 1997 Edition, Table 5-23: Sedentary Adult Mean 0.5 m\u00b3/h).",
    ),
    ActivityType.COMMUTING: ActivityProfile(
        activity_type=ActivityType.COMMUTING,
        display_name="Commuting (Transit)",
        inhalation_rate_m3_h=0.60,
        met_equivalent=1.5,
        description="Passive vehicle transit (bus, car, metro) with light seated alertness (~10.0 L/min).",
        reference="Zuurbier et al. (2009); US EPA Exposure Factors Handbook (2011 Edition), Table 6-2 (Light In-Vehicle Transit, <=1.5 MET).",
    ),
    ActivityType.WALKING: ActivityProfile(
        activity_type=ActivityType.WALKING,
        display_name="Walking (Moderate Pace)",
        inhalation_rate_m3_h=1.20,
        met_equivalent=3.0,
        description="Standard pedestrian walking at ~4-5 km/h with moderate respiratory demand (~20.0 L/min).",
        reference="Adams (1993); US EPA Exposure Factors Handbook (2011 Edition), Table 6-2 (Light/Moderate Intensity, 3.0 MET).",
    ),
    ActivityType.CYCLING: ActivityProfile(
        activity_type=ActivityType.CYCLING,
        display_name="Cycling (Outdoor Commute)",
        inhalation_rate_m3_h=2.10,
        met_equivalent=6.0,
        description="Moderate outdoor cycling (~15-18 km/h) with elevated tidal volume (~35.0 L/min).",
        reference="Int Panis et al. (2010); US EPA Exposure Factors Handbook (2011 Edition), Table 6-2 (Moderate Intensity 95th Percentile, 6.0 MET).",
    ),
    ActivityType.RUNNING: ActivityProfile(
        activity_type=ActivityType.RUNNING,
        display_name="Running / Jogging",
        inhalation_rate_m3_h=2.80,
        met_equivalent=8.0,
        description="Vigorous aerobic running (~8-10 km/h) with high minute ventilation (~46.7 L/min).",
        reference="Adams (1993); US EPA Exposure Factors Handbook (2011 Edition), Table 6-2 (High Intensity Adult Mean, 8.0 MET).",
    ),
}

# Standard criteria pollutant unit specifications
POLLUTANT_UNITS = {
    "PM2.5": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "PM10": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "NO2": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "SO2": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "CO": {"conc": "mg/m³", "exposure": "mg·h/m³", "mass": "mg"},
    "O3": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "NH3": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
    "PB": {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"},
}

CALCULATION_METHODOLOGY_NOTE = (
    "Methodology & Formulations:\n"
    "1. Concentration-Time Exposure = Ambient Concentration (C) × Duration (t in hours).\n"
    "   Units: µg·h/m³ (mg·h/m³ for Carbon Monoxide).\n"
    "2. Estimated Inhaled Mass = Ambient Concentration (C) × Ventilation Rate (V_E) × Duration (t in hours).\n"
    "   Units: µg (mg for Carbon Monoxide).\n"
    "3. Total Air Inhaled = Ventilation Rate (V_E) × Duration (t in hours) [m³].\n"
    "Assumptions: Adult mean minute ventilation rates derived from US EPA Exposure Factors Handbook (2011, Chapter 6, Table 6-2).\n"
    "4. Averaging-Period Compatibility: Ambient monitoring inputs follow statutory regulatory periods (24-hour running averages for PM2.5, PM10, NO2, SO2, NH3, Pb; 8-hour running averages for CO and O3). Simulating sub-daily activity sessions assumes temporal concentration uniformity across the session window. Real-world short-term transient spikes or diurnal peaks may deviate from the 24-hr/8-hr average.\n"
    "Distinct Pollutant Integrity: Criteria pollutants are never summed into an arbitrary single composite score."
)

EXPOSURE_NON_MEDICAL_DISCLAIMER = (
    "Scientific Environmental Advisory: AirGuard AI provides deterministic physical exposure estimates "
    "based on ambient monitoring data and respiratory ventilation factors. Estimated inhaled mass represents "
    "gross air intake and does NOT represent absorbed internal dose or deposited pulmonary fraction. "
    "This simulation does not constitute clinical diagnostic advice, personal health forecasting, or a guarantee of safety."
)


def get_activity_profile(activity_type: ActivityType) -> ActivityProfile:
    """Retrieves standard activity profile or defaults to Walking."""
    return ACTIVITY_PROFILES.get(activity_type, ACTIVITY_PROFILES[ActivityType.WALKING])


def calculate_concentration_time_exposure(
    concentration: Optional[float],
    duration_hours: float,
    pollutant: str,
) -> Tuple[Optional[float], str]:
    """
    Calculates cumulative concentration-time exposure:
    Exposure Index = Ambient Concentration × Exposure Duration (hours).
    """
    pol_key = pollutant.upper().replace("_", ".")
    unit_spec = POLLUTANT_UNITS.get(pol_key, {"exposure": "µg·h/m³"})
    exposure_unit = unit_spec["exposure"]

    if concentration is None:
        return None, exposure_unit

    if concentration < 0.0:
        raise ValueError(f"Ambient concentration for {pollutant} cannot be negative: {concentration}")
    if duration_hours < 0.0:
        raise ValueError(f"Duration cannot be negative: {duration_hours}")

    exp_val = round(concentration * duration_hours, 2)
    return exp_val, exposure_unit


def calculate_inhaled_mass(
    concentration: Optional[float],
    inhalation_rate_m3_h: float,
    duration_hours: float,
    pollutant: str,
) -> Tuple[Optional[float], str]:
    """
    Calculates estimated gross inhaled pollutant mass:
    Inhaled Mass = Concentration × Inhalation Rate × Duration (hours).
    """
    pol_key = pollutant.upper().replace("_", ".")
    unit_spec = POLLUTANT_UNITS.get(pol_key, {"mass": "µg"})
    mass_unit = unit_spec["mass"]

    if concentration is None:
        return None, mass_unit

    if concentration < 0.0:
        raise ValueError(f"Ambient concentration for {pollutant} cannot be negative: {concentration}")
    if inhalation_rate_m3_h <= 0.0:
        raise ValueError(f"Inhalation rate must be positive: {inhalation_rate_m3_h}")
    if duration_hours < 0.0:
        raise ValueError(f"Duration cannot be negative: {duration_hours}")

    mass_val = round(concentration * inhalation_rate_m3_h * duration_hours, 2)
    return mass_val, mass_unit


def compute_all_pollutant_metrics(
    concentrations: Dict[str, Optional[float]],
    activity: ActivityProfile,
    duration_minutes: int,
) -> Dict[str, PollutantExposureMetric]:
    """
    Computes pollutant-specific concentration-time exposure and estimated inhaled mass
    for all criteria pollutants present in input concentrations.
    Preserves missing pollutant values as None (never coerced to 0).
    """
    duration_hours = duration_minutes / 60.0
    metrics: Dict[str, PollutantExposureMetric] = {}

    for pol, conc in concentrations.items():
        pol_upper = pol.upper().replace("_", ".")
        unit_spec = POLLUTANT_UNITS.get(pol_upper, {"conc": "µg/m³", "exposure": "µg·h/m³", "mass": "µg"})

        if conc is not None:
            exp_val, exp_unit = calculate_concentration_time_exposure(conc, duration_hours, pol_upper)
            mass_val, mass_unit = calculate_inhaled_mass(conc, activity.inhalation_rate_m3_h, duration_hours, pol_upper)
            is_avail = True
        else:
            exp_val = None
            exp_unit = unit_spec["exposure"]
            mass_val = None
            mass_unit = unit_spec["mass"]
            is_avail = False

        metrics[pol_upper] = PollutantExposureMetric(
            pollutant=pol_upper,
            ambient_concentration=conc,
            concentration_unit=unit_spec["conc"],
            concentration_time_exposure=exp_val,
            exposure_unit=exp_unit,
            inhalation_rate_m3_h=activity.inhalation_rate_m3_h,
            estimated_inhaled_mass=mass_val,
            mass_unit=mass_unit,
            is_available=is_avail,
        )

    return metrics


def compare_scenarios(
    sim_a: ExposureSimulationResponse,
    sim_b: ExposureSimulationResponse,
    label_a: str = "Scenario A",
    label_b: str = "Scenario B",
) -> Tuple[Dict[str, PollutantComparisonDelta], str]:
    """
    Computes rigorous physical delta comparison between Scenario A and Scenario B.
    Never claims medical safety; transparently reports duration, ventilation rate, and mass differences.
    """
    deltas: Dict[str, PollutantComparisonDelta] = {}

    # Union of all pollutants across both scenarios
    all_pols = sorted(list(set(sim_a.pollutants.keys()) | set(sim_b.pollutants.keys())))

    mass_changes_summary: List[str] = []

    for pol in all_pols:
        metric_a = sim_a.pollutants.get(pol)
        metric_b = sim_b.pollutants.get(pol)

        exp_a = metric_a.concentration_time_exposure if metric_a and metric_a.is_available else None
        exp_b = metric_b.concentration_time_exposure if metric_b and metric_b.is_available else None
        delta_exp = round(exp_b - exp_a, 2) if (exp_a is not None and exp_b is not None) else None

        mass_a = metric_a.estimated_inhaled_mass if metric_a and metric_a.is_available else None
        mass_b = metric_b.estimated_inhaled_mass if metric_b and metric_b.is_available else None
        delta_mass = round(mass_b - mass_a, 2) if (mass_a is not None and mass_b is not None) else None

        pct_change = None
        if mass_a is not None and mass_b is not None:
            if mass_a > 0.0:
                pct_change = round(((mass_b - mass_a) / mass_a) * 100.0, 1)
            elif mass_b == 0.0:
                pct_change = 0.0

        unit_spec = POLLUTANT_UNITS.get(pol, {"exposure": "µg·h/m³", "mass": "µg"})
        exp_unit = unit_spec["exposure"]
        mass_unit = unit_spec["mass"]

        # Formulate pollutant-specific summary
        if mass_a is not None and mass_b is not None:
            if delta_mass > 0:
                p_sum = (
                    f"{label_b} increases estimated inhaled {pol} mass by {abs(delta_mass):.2f} {mass_unit} "
                    f"(+{pct_change:.1f}%) compared to {label_a}."
                )
            elif delta_mass < 0:
                p_sum = (
                    f"{label_b} reduces estimated inhaled {pol} mass by {abs(delta_mass):.2f} {mass_unit} "
                    f"({pct_change:.1f}%) compared to {label_a}."
                )
            else:
                p_sum = f"{label_b} and {label_a} have identical estimated inhaled {pol} mass ({mass_a:.2f} {mass_unit})."
            mass_changes_summary.append(p_sum)
        else:
            p_sum = f"Insufficient continuous data for {pol} across both scenarios."

        deltas[pol] = PollutantComparisonDelta(
            pollutant=pol,
            scenario_a_exposure=exp_a,
            scenario_b_exposure=exp_b,
            delta_exposure=delta_exp,
            exposure_unit=exp_unit,
            scenario_a_inhaled_mass=mass_a,
            scenario_b_inhaled_mass=mass_b,
            delta_inhaled_mass=delta_mass,
            mass_unit=mass_unit,
            percent_change_inhaled_mass=pct_change,
            summary=p_sum,
        )

    # Physical comparison narrative
    dur_ratio = sim_b.duration_hours / sim_a.duration_hours if sim_a.duration_hours > 0 else 1.0
    vent_ratio = (
        sim_b.activity.inhalation_rate_m3_h / sim_a.activity.inhalation_rate_m3_h
        if sim_a.activity.inhalation_rate_m3_h > 0
        else 1.0
    )
    vol_a = sim_a.total_inhaled_volume_m3
    vol_b = sim_b.total_inhaled_volume_m3
    delta_vol = round(vol_b - vol_a, 2)

    physical_summary = (
        f"Physical Comparison Analysis:\n"
        f"• Duration: {label_a} ({sim_a.duration_minutes}m) vs {label_b} ({sim_b.duration_minutes}m) "
        f"[Ratio: {dur_ratio:.2f}x].\n"
        f"• Activity & Inhalation: {sim_a.activity.display_name} ({sim_a.activity.inhalation_rate_m3_h} m³/h) vs "
        f"{sim_b.activity.display_name} ({sim_b.activity.inhalation_rate_m3_h} m³/h) [Ventilation Ratio: {vent_ratio:.2f}x].\n"
        f"• Total Inhaled Air Volume: {vol_a:.2f} m³ ({label_a}) vs {vol_b:.2f} m³ ({label_b}) [Delta: {delta_vol:+.2f} m³].\n"
        f"Key Pollutant Impacts:\n" + "\n".join(f"• {s}" for s in mass_changes_summary[:3])
    )

    return deltas, physical_summary
