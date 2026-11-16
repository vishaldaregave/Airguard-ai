"""
AirGuard AI - Pure Modular Spatial Interpolation Engine
Implements Inverse Distance Weighting (IDW) for atmospheric pollutant estimation.
Zero synthetic assumptions. Strictly causal and transparent scientific estimation.
"""
from datetime import datetime, timezone
import math
from typing import Dict, List, Optional, Tuple

from app.schemas.pollutant import DataSourceType, LocationCoordinate, PollutantType
from app.schemas.geo import (
    ContributingStation,
    GeoObservationItem,
    InterpolatedPollutant,
    InterpolationStatus,
    SpatialInterpolationResponse,
    StationType,
)
from app.engine.cpcb_aqi import calculate_cpcb_aqi, calculate_sub_index
from app.services.geo import haversine_distance_km


# Standard pollutant mapping to PollutantType enum
POLLUTANT_ENUM_MAP: Dict[str, PollutantType] = {
    "pm2_5": PollutantType.PM2_5,
    "pm10": PollutantType.PM10,
    "no2": PollutantType.NO2,
    "so2": PollutantType.SO2,
    "co": PollutantType.CO,
    "o3": PollutantType.O3,
    "nh3": PollutantType.NH3,
    "pb": PollutantType.PB,
}

CRITERIA_POLLUTANTS = ["pm2_5", "pm10", "no2", "so2", "co", "o3", "nh3", "pb"]


def calculate_angular_gap(
    target_lat: float,
    target_lon: float,
    station_coords: List[Tuple[float, float]],
) -> float:
    """
    Computes the maximum azimuthal angular gap between stations surrounding the target location.
    If max angular gap > 180 degrees, all stations lie on one side of the target (extrapolation).
    """
    if len(station_coords) < 2:
        return 360.0

    angles: List[float] = []
    lat0_rad = math.radians(target_lat)
    cos_lat0 = math.cos(lat0_rad)

    for s_lat, s_lon in station_coords:
        d_lat = math.radians(s_lat - target_lat)
        d_lon = math.radians(s_lon - target_lon)
        # Planar azimuthal projection around local origin
        x = d_lon * cos_lat0
        y = d_lat
        angle = math.atan2(y, x)
        angle_deg = math.degrees(angle) % 360.0
        angles.append(angle_deg)

    angles.sort()
    max_gap = 0.0
    n = len(angles)
    for i in range(n):
        next_i = (i + 1) % n
        gap = (angles[next_i] - angles[i]) % 360.0
        if gap > max_gap:
            max_gap = gap

    return round(max_gap, 1)


def calculate_spatial_uncertainty(
    min_dist_km: float,
    mean_dist_km: float,
    station_count: int,
    max_radius_km: float,
    max_angular_gap_deg: float,
    optimal_station_count: int = 6,
) -> float:
    """
    Calculates a scientific spatial uncertainty score in [0.0, 100.0].
    Higher scores indicate higher spatial uncertainty due to:
    1. Distance from contributing stations (40% weight)
    2. Density / station count shortfall (30% weight)
    3. Directional anisotropy / angular gap (30% weight)
    """
    # 1. Distance factor: proximity of nearest and average station
    dist_ratio = min(1.0, mean_dist_km / max_radius_km)
    dist_score = dist_ratio * 100.0

    # 2. Count factor: shortage compared to optimal spatial sample
    count_score = max(0.0, 100.0 - (station_count / float(optimal_station_count)) * 100.0)

    # 3. Angular factor: if stations all lie on one side (gap > 180 deg), extrapolation penalty
    if max_angular_gap_deg <= 90.0:
        angle_score = 10.0
    elif max_angular_gap_deg <= 180.0:
        angle_score = 30.0 + ((max_angular_gap_deg - 90.0) / 90.0) * 30.0
    else:
        # Extrapolation regime: 180 to 360 deg
        angle_score = 60.0 + ((max_angular_gap_deg - 180.0) / 180.0) * 40.0

    composite = (0.40 * dist_score) + (0.30 * count_score) + (0.30 * angle_score)
    # Collocated stations have near-zero uncertainty
    if min_dist_km < 0.1:
        composite = min(composite, 15.0)

    return round(min(100.0, max(0.0, composite)), 1)


class SpatialInterpolator:
    """
    Inverse Distance Weighting (IDW) spatial interpolator for environmental pollutant fields.
    """

    def __init__(
        self,
        power_parameter: float = 2.0,
        max_search_radius_km: float = 50.0,
        min_stations: int = 3,
        collocation_threshold_km: float = 0.05,
        max_staleness_minutes: float = 120.0,
    ):
        self.power = power_parameter
        self.max_radius_km = max_search_radius_km
        self.min_stations = min_stations
        self.collocation_threshold_km = collocation_threshold_km
        self.max_staleness_minutes = max_staleness_minutes

    def interpolate(
        self,
        target_lat: float,
        target_lon: float,
        observations: List[GeoObservationItem],
        allow_demo: bool = False,
        search_radius_km: Optional[float] = None,
        min_stations: Optional[int] = None,
    ) -> SpatialInterpolationResponse:
        """
        Executes IDW spatial interpolation for a given target coordinate.
        """
        effective_radius = search_radius_km or self.max_radius_km
        effective_min_stations = min_stations or self.min_stations

        target_coord = LocationCoordinate(
            latitude=target_lat,
            longitude=target_lon,
            city="Interpolated Query Point",
            country="India",
        )
        now_utc = datetime.now(timezone.utc)

        # 1. Coordinate Validation
        if not (-90.0 <= target_lat <= 90.0 and -180.0 <= target_lon <= 180.0):
            return SpatialInterpolationResponse(
                target_location=target_coord,
                status=InterpolationStatus.INVALID_INPUT,
                search_radius_km=effective_radius,
                contributing_station_count=0,
                spatial_uncertainty_score=100.0,
                timestamp=now_utc,
            )

        # 2. Filter Observations by Quality, Staleness, and Provenance
        eligible_obs: List[Tuple[GeoObservationItem, float]] = []
        has_stale_inputs = False

        for obs in observations:
            # Exclude demo fixtures unless explicitly enabled
            if obs.data_source_type == DataSourceType.DEMO_FIXTURE and not allow_demo:
                continue

            # Check staleness
            if obs.is_stale or (
                obs.data_freshness_minutes is not None
                and obs.data_freshness_minutes > self.max_staleness_minutes
            ):
                has_stale_inputs = True
                continue

            # Compute distance
            d_km = haversine_distance_km(
                target_lat, target_lon, obs.location.latitude, obs.location.longitude
            )
            if d_km <= effective_radius:
                eligible_obs.append((obs, d_km))

        # Check coverage
        if not eligible_obs:
            status = InterpolationStatus.STALE_INPUTS if has_stale_inputs else InterpolationStatus.INSUFFICIENT_COVERAGE
            return SpatialInterpolationResponse(
                target_location=target_coord,
                status=status,
                search_radius_km=effective_radius,
                contributing_station_count=0,
                spatial_uncertainty_score=100.0,
                timestamp=now_utc,
            )

        # 3. Physical Monitors Preference Policy:
        # If sufficient physical stations exist, exclude atmospheric model grid points from IDW.
        physical_eligible = [
            (obs, d) for obs, d in eligible_obs if obs.station_type == StationType.PHYSICAL_MONITOR
        ]
        if len(physical_eligible) >= effective_min_stations:
            active_pool = physical_eligible
        else:
            active_pool = eligible_obs

        # Check minimum station count constraint
        if len(active_pool) < effective_min_stations:
            return SpatialInterpolationResponse(
                target_location=target_coord,
                status=InterpolationStatus.INSUFFICIENT_STATIONS,
                search_radius_km=effective_radius,
                contributing_station_count=len(active_pool),
                spatial_uncertainty_score=90.0,
                timestamp=now_utc,
            )

        # 4. Check for Exact Collocation (< collocation_threshold_km)
        active_pool.sort(key=lambda item: item[1])
        nearest_obs, nearest_dist = active_pool[0]
        is_collocated = nearest_dist <= self.collocation_threshold_km

        # 5. IDW Computation per Pollutant
        interpolated_pollutants: Dict[str, InterpolatedPollutant] = {}
        all_contributing_ids = set()

        for pol_key in CRITERIA_POLLUTANTS:
            # Extract stations monitoring this pollutant with consistent averaging periods
            pol_stations: List[Tuple[GeoObservationItem, float, float, int, str]] = []
            for obs, dist in active_pool:
                val = getattr(obs, pol_key, None)
                if val is not None and val >= 0.0:
                    avg_hours = obs.pollutant_averaging_hours.get(pol_key, 24)
                    unit = obs.pollutant_units.get(pol_key, "µg/m³" if pol_key != "co" else "mg/m³")
                    pol_stations.append((obs, dist, val, avg_hours, unit))

            if not pol_stations:
                continue

            # Verify consistent averaging period (filter to dominant averaging period)
            period_counts: Dict[int, int] = {}
            for _, _, _, avg_h, _ in pol_stations:
                period_counts[avg_h] = period_counts.get(avg_h, 0) + 1
            dominant_period = max(period_counts.keys(), key=lambda k: period_counts[k])
            compatible_stations = [s for s in pol_stations if s[3] == dominant_period]

            # At least 1 station required to interpolate a pollutant if overall count >= min_stations
            if not compatible_stations:
                continue

            # Calculate IDW weights
            if is_collocated:
                collocated_match = next((s for s in compatible_stations if s[1] <= self.collocation_threshold_km), None)
                if collocated_match:
                    est_val = collocated_match[2]
                    unit = collocated_match[4]
                    avg_h = collocated_match[3]
                    contributors = [
                        ContributingStation(
                            station_id=collocated_match[0].station_id,
                            station_name=collocated_match[0].station_name,
                            provider=collocated_match[0].provider,
                            station_type=collocated_match[0].station_type,
                            distance_km=collocated_match[1],
                            weight=1.0,
                            pollutant_value=est_val,
                            averaging_hours=avg_h,
                            unit=unit,
                            data_source_type=collocated_match[0].data_source_type,
                        )
                    ]
                    all_contributing_ids.add(collocated_match[0].station_id)
                else:
                    est_val, avg_h, unit, contributors = self._calc_idw_weights(compatible_stations)
                    for c in contributors:
                        all_contributing_ids.add(c.station_id)
            else:
                est_val, avg_h, unit, contributors = self._calc_idw_weights(compatible_stations)
                for c in contributors:
                    all_contributing_ids.add(c.station_id)

            # Calculate CPCB sub-index for estimated pollutant
            pol_enum = POLLUTANT_ENUM_MAP.get(pol_key)
            sub_idx_res = calculate_sub_index(pol_enum, est_val) if pol_enum else None
            sub_idx = sub_idx_res.sub_index if sub_idx_res else None

            interpolated_pollutants[pol_key] = InterpolatedPollutant(
                pollutant=pol_key,
                estimated_value=round(est_val, 2),
                unit=unit,
                averaging_hours=avg_h,
                sub_index=sub_idx,
                contributing_stations=contributors,
            )

        # 6. Overall CPCB AQI Calculation on Synthesized Observation
        from app.schemas.pollutant import EnvironmentalObservationInput
        synth_obs = EnvironmentalObservationInput(
            station_id="IDW-INTERPOLATED",
            station_name=f"Interpolated Point ({target_lat:.4f}, {target_lon:.4f})",
            location=target_coord,
            timestamp=now_utc,
            provider="AIRGUARD Spatial Interpolation",
            data_source_type=DataSourceType.ESTIMATED,
            pm2_5=interpolated_pollutants["pm2_5"].estimated_value if "pm2_5" in interpolated_pollutants else None,
            pm10=interpolated_pollutants["pm10"].estimated_value if "pm10" in interpolated_pollutants else None,
            no2=interpolated_pollutants["no2"].estimated_value if "no2" in interpolated_pollutants else None,
            so2=interpolated_pollutants["so2"].estimated_value if "so2" in interpolated_pollutants else None,
            co=interpolated_pollutants["co"].estimated_value if "co" in interpolated_pollutants else None,
            o3=interpolated_pollutants["o3"].estimated_value if "o3" in interpolated_pollutants else None,
            nh3=interpolated_pollutants["nh3"].estimated_value if "nh3" in interpolated_pollutants else None,
            pb=interpolated_pollutants["pb"].estimated_value if "pb" in interpolated_pollutants else None,
        )

        cpcb_res = calculate_cpcb_aqi(synth_obs)
        overall_aqi = cpcb_res.overall_aqi
        category = cpcb_res.category.value if cpcb_res.category else None
        dominant_pol = (
            cpcb_res.prominent_pollutant.value
            if hasattr(cpcb_res.prominent_pollutant, "value")
            else cpcb_res.prominent_pollutant
        )

        # 7. Spatial Uncertainty Calculation
        station_coords = [(obs.location.latitude, obs.location.longitude) for obs, _ in active_pool]
        distances = [d for _, d in active_pool]
        mean_dist = sum(distances) / float(len(distances))
        min_dist = distances[0]
        max_gap_deg = calculate_angular_gap(target_lat, target_lon, station_coords)

        uncertainty_score = calculate_spatial_uncertainty(
            min_dist_km=min_dist,
            mean_dist_km=mean_dist,
            station_count=len(active_pool),
            max_radius_km=effective_radius,
            max_angular_gap_deg=max_gap_deg,
        )

        return SpatialInterpolationResponse(
            target_location=target_coord,
            status=InterpolationStatus.INTERPOLATED,
            data_source_type=DataSourceType.ESTIMATED,
            is_interpolated=True,
            method="INVERSE_DISTANCE_WEIGHTING",
            power_parameter=self.power,
            search_radius_km=effective_radius,
            interpolated_aqi=overall_aqi,
            cpcb_category=category,
            dominant_pollutant=dominant_pol,
            pollutants=interpolated_pollutants,
            contributing_station_count=len(all_contributing_ids),
            spatial_uncertainty_score=uncertainty_score,
            timestamp=now_utc,
        )

    def _calc_idw_weights(
        self,
        stations: List[Tuple[GeoObservationItem, float, float, int, str]],
    ) -> Tuple[float, int, str, List[ContributingStation]]:
        """
        Calculates IDW weighted average and contributing station breakdown.
        """
        # Sum raw weights: w_i = 1 / (d_i ^ p)
        raw_weights: List[float] = []
        for _, dist, _, _, _ in stations:
            # Small clamp to prevent division by zero
            clamped_dist = max(dist, 0.001)
            raw_w = 1.0 / (clamped_dist ** self.power)
            raw_weights.append(raw_w)

        sum_raw_w = sum(raw_weights)
        norm_weights = [rw / sum_raw_w for rw in raw_weights]

        weighted_sum = 0.0
        contributors: List[ContributingStation] = []

        avg_hours = stations[0][3]
        unit = stations[0][4]

        for i, (obs, dist, val, h, u) in enumerate(stations):
            w = norm_weights[i]
            weighted_sum += w * val
            contributors.append(
                ContributingStation(
                    station_id=obs.station_id,
                    station_name=obs.station_name,
                    provider=obs.provider,
                    station_type=obs.station_type,
                    distance_km=dist,
                    weight=round(w, 4),
                    pollutant_value=val,
                    averaging_hours=h,
                    unit=u,
                    data_source_type=obs.data_source_type,
                )
            )

        return weighted_sum, avg_hours, unit, contributors


# Singleton instance
spatial_interpolator = SpatialInterpolator()
