"""
AirGuard AI - Historical Analytics & Environmental Intelligence Engine
Pure deterministic, modular mathematical engine for environmental time-series analytics,
trend evaluation, diurnal profiling, peak episode detection, calendar aggregation,
and rigorous location comparisons with provenance preservation.
"""
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple, Any
import math

from app.schemas.history import (
    CalendarDayItem,
    CalendarDayStatus,
    DataGapItem,
    HistoricalDataPoint,
    PeakEpisodeItem,
    PollutantSummaryItem,
    PollutantTrendItem,
    TrendDirection,
)

# Standard CPCB NAAQS 24-Hour Regulatory Limits (Schedule VII)
CPCB_24H_STANDARDS = {
    "PM2.5": 60.0,   # µg/m³
    "PM10": 100.0,   # µg/m³
    "NO2": 80.0,     # µg/m³
    "SO2": 80.0,     # µg/m³
    "CO": 2.0,       # mg/m³ (8-hour standard: 2.0 mg/m³)
    "O3": 100.0,     # µg/m³ (8-hour standard: 100.0 µg/m³)
    "NH3": 400.0,    # µg/m³
    "PB": 1.0,       # µg/m³
}

POLLUTANT_UNITS = {
    "PM2.5": "µg/m³",
    "PM10": "µg/m³",
    "NO2": "µg/m³",
    "SO2": "µg/m³",
    "CO": "mg/m³",
    "O3": "µg/m³",
    "NH3": "µg/m³",
    "PB": "µg/m³",
}

CPCB_16_HOUR_DISCLOSURE = (
    "Statutory CPCB NAAQS 16-Hour Minimum Rule: Central Pollution Control Board guidelines require "
    "at least 16 hourly observations out of 24 (66.7% daily coverage) to formulate a valid statutory daily AQI. "
    "Days with fewer than 16 samples are marked as INSUFFICIENT_SAMPLES and any representative index is provisional."
)

HISTORICAL_NON_CAUSAL_DISCLAIMER = (
    "Scientific Environmental Advisory: Historical statistics, trends, and diurnal cycles reflect empirical "
    "ambient air-quality observations and atmospheric transport models. In accordance with scientific integrity, "
    "AirGuard AI reports observed correlation without claiming unverified causal origins (e.g. traffic or industrial sources) "
    "and does not present exposure statistics as medical diagnoses or clinical health predictions."
)


# =========================================================================
# 1. MATHEMATICAL TREND EVALUATION (ORDINARY LEAST SQUARES)
# =========================================================================

def calculate_linear_trend(
    timestamps: List[datetime],
    values: List[float],
    min_samples: int = 6,
    slope_threshold_per_day: float = 2.0,
    r2_threshold: float = 0.20,
) -> Tuple[TrendDirection, float, float, bool]:
    """
    Computes linear regression trend over chronological time points:
    y = m * x + c, where x is elapsed time in decimal days.

    Returns:
        (TrendDirection, slope_per_day, r_squared, p_value_significant)
    """
    if len(timestamps) != len(values) or len(values) < min_samples:
        return TrendDirection.INSUFFICIENT_DATA, 0.0, 0.0, False

    # Filter out None/NaN values
    valid_pairs = [(t, v) for t, v in zip(timestamps, values) if v is not None and not math.isnan(v)]
    if len(valid_pairs) < min_samples:
        return TrendDirection.INSUFFICIENT_DATA, 0.0, 0.0, False

    t0 = min(p[0] for p in valid_pairs)
    x_vals = [(p[0] - t0).total_seconds() / 86400.0 for p in valid_pairs]
    y_vals = [p[1] for p in valid_pairs]

    n = len(x_vals)
    mean_x = sum(x_vals) / n
    mean_y = sum(y_vals) / n

    denom = sum((x - mean_x) ** 2 for x in x_vals)
    if denom <= 1e-9:
        return TrendDirection.STABLE, 0.0, 0.0, False

    numer = sum((x - mean_x) * (y - mean_y) for x, y in zip(x_vals, y_vals))
    slope = numer / denom

    ss_tot = sum((y - mean_y) ** 2 for y in y_vals)
    if ss_tot <= 1e-9:
        return TrendDirection.STABLE, round(slope, 2), 0.0, False

    ss_res = sum((y - (mean_y + slope * (x - mean_x))) ** 2 for x, y in zip(x_vals, y_vals))
    r_squared = max(0.0, min(1.0, 1.0 - (ss_res / ss_tot)))

    # Significance: R² >= threshold and slope magnitude >= slope_threshold_per_day
    is_significant = (r_squared >= r2_threshold) and (abs(slope) >= slope_threshold_per_day)

    if is_significant:
        direction = TrendDirection.INCREASING if slope > 0 else TrendDirection.DECREASING
    else:
        direction = TrendDirection.STABLE

    return direction, round(slope, 2), round(r_squared, 3), is_significant


# =========================================================================
# 2. DATA GAP DETECTION
# =========================================================================

def detect_data_gaps(
    timestamps: List[datetime],
    expected_interval_hours: float = 1.0,
    gap_threshold_hours: float = 2.0,
) -> List[DataGapItem]:
    """
    Identifies missing data intervals where time elapsed between consecutive
    readings exceeds the gap threshold (default > 2.0 hours for hourly telemetry).
    """
    if len(timestamps) < 2:
        return []

    sorted_ts = sorted(timestamps)
    gaps: List[DataGapItem] = []

    for i in range(len(sorted_ts) - 1):
        t1 = sorted_ts[i]
        t2 = sorted_ts[i + 1]
        delta_h = (t2 - t1).total_seconds() / 3600.0

        if delta_h > gap_threshold_hours:
            gaps.append(
                DataGapItem(
                    start_time=t1,
                    end_time=t2,
                    duration_hours=round(delta_h, 1),
                    reason=f"Missing observation telemetry window ({delta_h:.1f} hours without records)",
                )
            )

    return gaps


# =========================================================================
# 3. STATISTICAL SUMMARIES & POLLUTANT AGGREGATION
# =========================================================================

def compute_pollutant_statistics(
    pollutant: str,
    values: List[Optional[float]],
    total_expected_samples: int,
) -> PollutantSummaryItem:
    """
    Computes rigorous descriptive statistics for a pollutant series.
    Never silently fills missing observations with zero.
    """
    valid = [v for v in values if v is not None and not math.isnan(v)]
    unit = POLLUTANT_UNITS.get(pollutant.upper().replace("_", "."), "µg/m³")
    std_limit = CPCB_24H_STANDARDS.get(pollutant.upper().replace("_", "."))

    if not valid:
        return PollutantSummaryItem(
            pollutant=pollutant,
            mean=None,
            median=None,
            min_value=None,
            max_value=None,
            standard_deviation=None,
            valid_samples_count=0,
            completeness_pct=0.0,
            unit=unit,
            averaging_period_hours=24 if pollutant.upper() != "CO" else 8,
            statutory_standard_exceeded_count=0,
        )

    valid_sorted = sorted(valid)
    n = len(valid_sorted)
    mean_val = sum(valid_sorted) / n
    median_val = valid_sorted[n // 2] if n % 2 != 0 else (valid_sorted[n // 2 - 1] + valid_sorted[n // 2]) / 2.0
    min_val = valid_sorted[0]
    max_val = valid_sorted[-1]

    variance = sum((x - mean_val) ** 2 for x in valid_sorted) / n if n > 1 else 0.0
    std_dev = math.sqrt(variance)

    exceeded_count = 0
    if std_limit is not None:
        exceeded_count = sum(1 for v in valid if v > std_limit)

    completeness = round((n / max(total_expected_samples, 1)) * 100.0, 1)

    return PollutantSummaryItem(
        pollutant=pollutant,
        mean=round(mean_val, 1),
        median=round(median_val, 1),
        min_value=round(min_val, 1),
        max_value=round(max_val, 1),
        standard_deviation=round(std_dev, 2),
        valid_samples_count=n,
        completeness_pct=min(100.0, completeness),
        unit=unit,
        averaging_period_hours=8 if pollutant.upper() in ("CO", "O3") else 24,
        statutory_standard_exceeded_count=exceeded_count,
    )


# =========================================================================
# 4. DIURNAL PROFILING
# =========================================================================

def compute_diurnal_profile(
    observations: List[Any],
    timezone_offset_hours: float = 5.5,
) -> Dict[int, Optional[float]]:
    """
    Computes local diurnal profile: mean AQI (or PM2.5) for each hour of day (0 to 23).
    Preserves hours with no data as None.
    """
    hourly_buckets: Dict[int, List[float]] = {h: [] for h in range(24)}

    for obs in observations:
        ts = getattr(obs, "timestamp", None)
        if ts is None:
            continue
        local_ts = ts + timedelta(hours=timezone_offset_hours)
        h = local_ts.hour

        val = getattr(obs, "calculated_aqi", None)
        if val is None:
            val = getattr(obs, "pm2_5", None)
        if val is not None and not math.isnan(val):
            hourly_buckets[h].append(float(val))

    profile: Dict[int, Optional[float]] = {}
    for h in range(24):
        vals = hourly_buckets[h]
        profile[h] = round(sum(vals) / len(vals), 1) if vals else None

    return profile


# =========================================================================
# 5. CALENDAR AGGREGATION & CPCB 16-HOUR RULE
# =========================================================================

def aggregate_calendar_days(
    observations: List[Any],
    start_date: datetime,
    end_date: datetime,
    timezone_offset_hours: float = 5.5,
) -> List[CalendarDayItem]:
    """
    Aggregates observations into discrete local calendar days.
    Enforces CPCB 16-Hour Minimum Rule:
    - Days with >= 16 hourly samples: AVAILABLE & is_cpcb_valid_day = True
    - Days with 1 to 15 samples: INSUFFICIENT_SAMPLES & provisional AQI
    - Days with 0 samples: UNAVAILABLE
    """
    local_start = (start_date + timedelta(hours=timezone_offset_hours)).date()
    local_end = (end_date + timedelta(hours=timezone_offset_hours)).date()

    # Bucket observations by local date
    by_date: Dict[str, List[Any]] = {}
    cur = local_start
    while cur <= local_end:
        by_date[cur.isoformat()] = []
        cur += timedelta(days=1)

    for obs in observations:
        ts = getattr(obs, "timestamp", None)
        if ts is None:
            continue
        loc_d = (ts + timedelta(hours=timezone_offset_hours)).date().isoformat()
        if loc_d in by_date:
            by_date[loc_d].append(obs)

    days_list: List[CalendarDayItem] = []
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    for d_str in sorted(by_date.keys()):
        obs_day = by_date[d_str]
        d_obj = datetime.strptime(d_str, "%Y-%m-%d").date()
        day_of_week = day_names[d_obj.weekday()]
        sample_count = len(obs_day)
        coverage_pct = round((sample_count / 24.0) * 100.0, 1)

        if sample_count >= 16:
            status = CalendarDayStatus.AVAILABLE
            is_valid = True
        elif sample_count > 0:
            status = CalendarDayStatus.INSUFFICIENT_SAMPLES
            is_valid = False
        else:
            status = CalendarDayStatus.UNAVAILABLE
            is_valid = False

        rep_aqi: Optional[int] = None
        aqi_cat: Optional[str] = None
        prom_pol: Optional[str] = None
        pol_means: Dict[str, Optional[float]] = {}

        if sample_count > 0:
            # Average AQI
            aqi_vals = [getattr(o, "calculated_aqi", None) for o in obs_day if getattr(o, "calculated_aqi", None) is not None]
            if aqi_vals:
                rep_aqi = int(round(sum(aqi_vals) / len(aqi_vals)))
                from app.engine.cpcb_aqi import get_aqi_category
                cat_enum = get_aqi_category(rep_aqi)
                aqi_cat = cat_enum.value if cat_enum else None

            # Dominant pollutant
            pol_counts: Dict[str, int] = {}
            for o in obs_day:
                pp = getattr(o, "prominent_pollutant", None)
                if pp:
                    pol_counts[pp] = pol_counts.get(pp, 0) + 1
            if pol_counts:
                prom_pol = max(pol_counts.items(), key=lambda x: x[1])[0]

            # Pollutant daily averages
            for p_attr, p_name in [
                ("pm2_5", "PM2.5"),
                ("pm10", "PM10"),
                ("no2", "NO2"),
                ("so2", "SO2"),
                ("co", "CO"),
                ("o3", "O3"),
            ]:
                vals = [getattr(o, p_attr, None) for o in obs_day if getattr(o, p_attr, None) is not None]
                pol_means[p_name] = round(sum(vals) / len(vals), 1) if vals else None

        days_list.append(
            CalendarDayItem(
                date=d_str,
                day_of_week=day_of_week,
                status=status,
                representative_aqi=rep_aqi,
                aqi_category=aqi_cat,
                prominent_pollutant=prom_pol,
                sample_count=sample_count,
                daily_coverage_pct=min(100.0, coverage_pct),
                is_cpcb_valid_day=is_valid,
                pollutant_means=pol_means,
            )
        )

    return days_list


# =========================================================================
# 6. EXTREME EPISODE DETECTION (PEAKS & CLEAN PERIODS)
# =========================================================================

def detect_extreme_episodes(
    observations: List[Any],
    elevated_threshold_aqi: int = 200,
    clean_threshold_aqi: int = 100,
    min_duration_hours: int = 2,
) -> Tuple[List[PeakEpisodeItem], List[PeakEpisodeItem]]:
    """
    Identifies continuous elevated and clean episodes without unverified causal claims.
    """
    if len(observations) < min_duration_hours:
        return [], []

    sorted_obs = sorted(observations, key=lambda o: getattr(o, "timestamp", datetime.min))
    peaks: List[PeakEpisodeItem] = []
    cleans: List[PeakEpisodeItem] = []

    # 1. Elevated Episodes
    current_peak_batch: List[Any] = []
    episode_idx = 1

    for o in sorted_obs:
        aqi = getattr(o, "calculated_aqi", None)
        if aqi is not None and aqi >= elevated_threshold_aqi:
            current_peak_batch.append(o)
        else:
            if len(current_peak_batch) >= min_duration_hours:
                # Close episode
                p_item = _build_episode_item(current_peak_batch, f"PEAK-{episode_idx:02d}", is_peak=True)
                peaks.append(p_item)
                episode_idx += 1
            current_peak_batch = []

    if len(current_peak_batch) >= min_duration_hours:
        peaks.append(_build_episode_item(current_peak_batch, f"PEAK-{episode_idx:02d}", is_peak=True))

    # 2. Clean Episodes
    current_clean_batch: List[Any] = []
    clean_idx = 1
    for o in sorted_obs:
        aqi = getattr(o, "calculated_aqi", None)
        if aqi is not None and aqi <= clean_threshold_aqi:
            current_clean_batch.append(o)
        else:
            if len(current_clean_batch) >= min_duration_hours:
                cleans.append(_build_episode_item(current_clean_batch, f"CLEAN-{clean_idx:02d}", is_peak=False))
                clean_idx += 1
            current_clean_batch = []

    if len(current_clean_batch) >= min_duration_hours:
        cleans.append(_build_episode_item(current_clean_batch, f"CLEAN-{clean_idx:02d}", is_peak=False))

    return peaks[:5], cleans[:5]


def _build_episode_item(batch: List[Any], ep_id: str, is_peak: bool) -> PeakEpisodeItem:
    t_start = getattr(batch[0], "timestamp")
    t_end = getattr(batch[-1], "timestamp")
    dur_h = round((t_end - t_start).total_seconds() / 3600.0 + 1.0, 1)

    if is_peak:
        peak_obs = max(batch, key=lambda o: getattr(o, "calculated_aqi", 0) or 0)
    else:
        peak_obs = min(batch, key=lambda o: getattr(o, "calculated_aqi", 999) or 999)

    peak_val = float(getattr(peak_obs, "calculated_aqi", 0) or 0)
    peak_time = getattr(peak_obs, "timestamp")

    from app.engine.cpcb_aqi import get_aqi_category
    cat = get_aqi_category(int(peak_val)).value if get_aqi_category(int(peak_val)) else "Moderate"

    temp = getattr(peak_obs, "temperature_celsius", None)
    wind = getattr(peak_obs, "wind_speed_kmh", None)
    hum = getattr(peak_obs, "relative_humidity_pct", None)

    mode_str = "Elevated pollution episode" if is_peak else "Favorable atmospheric dispersion period"
    desc = (
        f"{mode_str} lasting {dur_h} hours with peak AQI {peak_val:.0f} ({cat}). "
        f"Co-occurring meteorological indicators: temp {temp or 'N/A'} °C, wind {wind or 'N/A'} km/h."
    )

    return PeakEpisodeItem(
        episode_id=ep_id,
        pollutant_or_metric="CPCB AQI",
        peak_value=peak_val,
        start_time=t_start,
        peak_time=peak_time,
        end_time=t_end,
        duration_hours=dur_h,
        severity_category=cat,
        temperature_celsius=temp,
        wind_speed_kmh=wind,
        humidity_pct=hum,
        physical_description=desc,
    )


# =========================================================================
# 7. LOCATION COMPARISON LOGIC
# =========================================================================

def compare_historical_locations(
    loc_a: Any,
    loc_b: Any,
    label_a: str = "Location A",
    label_b: str = "Location B",
) -> Tuple[bool, str, Optional[float], Dict[str, Optional[float]], str]:
    """
    Rigorously compares two historical datasets:
    - Discloses physical monitor vs atmospheric model grid differences.
    - Computes delta AQI and delta pollutant concentrations.
    - Produces an objective, non-causal comparative summary.
    """
    is_phys_a = loc_a.is_physical_station
    is_phys_b = loc_b.is_physical_station

    compat_notes: List[str] = []
    is_compat = True

    if is_phys_a and not is_phys_b:
        compat_notes.append(
            f"Provenance Caveat: {label_a} is a physical monitoring station (in-situ point measurement), "
            f"whereas {label_b} is a chemical transport model grid (regional spatial volume estimate). "
            f"Local micro-source peaks observed at {label_a} may be smoothed out in the model grid."
        )
    elif not is_phys_a and is_phys_b:
        compat_notes.append(
            f"Provenance Caveat: {label_a} is a model grid whereas {label_b} is an in-situ physical monitor."
        )

    # Coverage comparison
    cov_a = loc_a.data_coverage_pct
    cov_b = loc_b.data_coverage_pct
    if abs(cov_a - cov_b) > 25.0:
        compat_notes.append(
            f"Data Coverage Asymmetry: {label_a} has {cov_a:.1f}% coverage vs {label_b} ({cov_b:.1f}%). "
            f"Direct comparisons should consider sampling density disparities."
        )

    compat_assessment = " ".join(compat_notes) if compat_notes else "Compatible observation datasets."

    # Deltas
    mean_aqi_a = loc_a.mean_aqi
    mean_aqi_b = loc_b.mean_aqi
    delta_aqi = round(mean_aqi_b - mean_aqi_a, 1) if (mean_aqi_a is not None and mean_aqi_b is not None) else None

    pol_deltas: Dict[str, Optional[float]] = {}
    pols = set(loc_a.pollutant_means.keys()) | set(loc_b.pollutant_means.keys())
    for p in sorted(list(pols)):
        va = loc_a.pollutant_means.get(p)
        vb = loc_b.pollutant_means.get(p)
        if va is not None and vb is not None:
            pol_deltas[p] = round(vb - va, 1)
        else:
            pol_deltas[p] = None

    # Summary narrative
    summary_parts = [
        f"Comparative Environmental Assessment between {label_a} ({loc_a.station_name}) and {label_b} ({loc_b.station_name}):"
    ]
    if delta_aqi is not None:
        if delta_aqi > 0:
            summary_parts.append(
                f"• Overall AQI: {label_b} averaged {abs(delta_aqi):.1f} points higher ({mean_aqi_b:.0f}) than {label_a} ({mean_aqi_a:.0f})."
            )
        elif delta_aqi < 0:
            summary_parts.append(
                f"• Overall AQI: {label_b} averaged {abs(delta_aqi):.1f} points lower ({mean_aqi_b:.0f}) than {label_a} ({mean_aqi_a:.0f})."
            )
        else:
            summary_parts.append(f"• Overall AQI: Both locations recorded identical average AQI ({mean_aqi_a:.0f}).")

    for p, d in pol_deltas.items():
        if d is not None:
            unit = POLLUTANT_UNITS.get(p, "µg/m³")
            sign = "+" if d > 0 else ""
            summary_parts.append(f"• {p}: Delta {sign}{d:.1f} {unit} ({label_b} vs {label_a}).")

    comparative_summary = "\n".join(summary_parts)

    return is_compat, compat_assessment, delta_aqi, pol_deltas, comparative_summary
