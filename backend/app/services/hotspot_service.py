"""
AirGuard AI - Deterministic Pollution Hotspot Detection Service
Identifies spatial clusters of elevated pollution while enforcing strict scientific rules:
1. Multi-station corroboration required (>= 2 stations) for confirmed hotspots.
2. Single isolated elevated readings are never labeled as confirmed hotspots.
3. Distinguishes measured (physical) from estimated (model-grid) clusters.
4. Transparent evidence, reasoning, and non-exact dispersion disclaimers.
"""
from datetime import datetime, timezone
import hashlib
from typing import Dict, List, Optional, Set, Tuple

from app.schemas.pollutant import DataSourceType, LocationCoordinate
from app.schemas.geo import (
    GeoHotspotsResponse,
    GeoObservationItem,
    HotspotCluster,
    HotspotSeverity,
    StationType,
)
from app.services.geo import haversine_distance_km


class HotspotDetectionService:
    """
    Deterministic spatial clustering engine for identifying regional pollution hotspots.
    """

    def __init__(
        self,
        cluster_distance_km: float = 15.0,
        elevated_aqi_threshold: int = 201,  # CPCB Poor, Very Poor, Severe
        elevated_pm25_threshold: float = 91.0,
        elevated_pm10_threshold: float = 251.0,
        max_staleness_minutes: float = 120.0,
    ):
        self.cluster_distance_km = cluster_distance_km
        self.elevated_aqi_threshold = elevated_aqi_threshold
        self.elevated_pm25_threshold = elevated_pm25_threshold
        self.elevated_pm10_threshold = elevated_pm10_threshold
        self.max_staleness_minutes = max_staleness_minutes

    def detect_hotspots(
        self,
        center_lat: float,
        center_lon: float,
        query_radius_km: float,
        observations: List[GeoObservationItem],
        allow_demo: bool = False,
    ) -> GeoHotspotsResponse:
        """
        Detects pollution hotspots among candidate observations within a search radius.
        """
        now_utc = datetime.now(timezone.utc)
        center_coord = LocationCoordinate(
            latitude=center_lat,
            longitude=center_lon,
            city="Query Center",
            country="India",
        )

        # 1. Filter Elevated, Fresh, and Geographically Valid Observations
        elevated_candidates: List[GeoObservationItem] = []
        for obs in observations:
            # Exclude demo fixtures unless explicitly allowed
            if obs.data_source_type == DataSourceType.DEMO_FIXTURE and not allow_demo:
                continue

            # Exclude stale data
            if obs.is_stale or (
                obs.data_freshness_minutes is not None
                and obs.data_freshness_minutes > self.max_staleness_minutes
            ):
                continue

            # Check if observation meets elevated pollution threshold
            is_elevated_aqi = obs.aqi is not None and obs.aqi >= self.elevated_aqi_threshold
            is_elevated_pm25 = obs.pm2_5 is not None and obs.pm2_5 >= self.elevated_pm25_threshold
            is_elevated_pm10 = obs.pm10 is not None and obs.pm10 >= self.elevated_pm10_threshold

            if is_elevated_aqi or is_elevated_pm25 or is_elevated_pm10:
                elevated_candidates.append(obs)

        if not elevated_candidates:
            return GeoHotspotsResponse(
                center_location=center_coord,
                query_radius_km=query_radius_km,
                hotspots=[],
                total_hotspots_count=0,
                timestamp=now_utc,
            )

        # 2. Spatial Clustering via Connected Components (Graph Adjacency within cluster_distance_km)
        n = len(elevated_candidates)
        adj: Dict[int, List[int]] = {i: [] for i in range(n)}
        for i in range(n):
            for j in range(i + 1, n):
                dist = haversine_distance_km(
                    elevated_candidates[i].location.latitude,
                    elevated_candidates[i].location.longitude,
                    elevated_candidates[j].location.latitude,
                    elevated_candidates[j].location.longitude,
                )
                if dist <= self.cluster_distance_km:
                    adj[i].append(j)
                    adj[j].append(i)

        visited: Set[int] = set()
        clusters: List[List[GeoObservationItem]] = []

        for i in range(n):
            if i not in visited:
                component: List[GeoObservationItem] = []
                queue = [i]
                visited.add(i)
                while queue:
                    curr = queue.pop(0)
                    component.append(elevated_candidates[curr])
                    for neighbor in adj[curr]:
                        if neighbor not in visited:
                            visited.add(neighbor)
                            queue.append(neighbor)
                clusters.append(component)

        # 3. Build HotspotCluster Objects with Rigorous Classification
        hotspot_items: List[HotspotCluster] = []

        for cluster_members in clusters:
            count = len(cluster_members)
            physical_count = sum(1 for m in cluster_members if m.station_type == StationType.PHYSICAL_MONITOR)

            # Calculate centroid
            sum_lat = sum(m.location.latitude for m in cluster_members)
            sum_lon = sum(m.location.longitude for m in cluster_members)
            centroid_lat = round(sum_lat / count, 5)
            centroid_lon = round(sum_lon / count, 5)

            # Calculate cluster radius (max distance from centroid)
            cluster_radius = 2.0  # default 2km for single point
            if count > 1:
                max_d = max(
                    haversine_distance_km(centroid_lat, centroid_lon, m.location.latitude, m.location.longitude)
                    for m in cluster_members
                )
                cluster_radius = max(2.0, round(max_d, 2))

            # Aggregate AQI & Pollutant metrics
            aqis = [m.aqi for m in cluster_members if m.aqi is not None]
            peak_aqi = max(aqis) if aqis else None
            mean_aqi = round(sum(aqis) / len(aqis), 1) if aqis else None

            pm25s = [m.pm2_5 for m in cluster_members if m.pm2_5 is not None]
            peak_pm25 = max(pm25s) if pm25s else None

            # Dominant pollutant
            dominant_counts: Dict[str, int] = {}
            for m in cluster_members:
                if m.dominant_pollutant:
                    dominant_counts[m.dominant_pollutant] = dominant_counts.get(m.dominant_pollutant, 0) + 1
            dominant_pol = max(dominant_counts.keys(), key=lambda k: dominant_counts[k]) if dominant_counts else "PM2.5"

            # Provenance determination: LIVE if all physical, ESTIMATED if model grids present
            all_physical = (physical_count == count)
            provenance = DataSourceType.LIVE if all_physical else DataSourceType.ESTIMATED

            station_ids = [m.station_id for m in cluster_members]
            station_names = [m.station_name for m in cluster_members]

            # Deterministic cluster ID
            id_str = f"{centroid_lat:.3f}:{centroid_lon:.3f}:{'-'.join(sorted(station_ids))}"
            cluster_id = f"HOTSPOT-{hashlib.md5(id_str.encode()).hexdigest()[:8]}"

            # Multi-station rule evaluation
            if count >= 2:
                is_confirmed = True
                if (peak_aqi and peak_aqi >= 401) or (peak_pm25 and peak_pm25 >= 250.0):
                    severity = HotspotSeverity.SEVERE_HOTSPOT
                elif (peak_aqi and peak_aqi >= 301) or (peak_pm25 and peak_pm25 >= 121.0):
                    severity = HotspotSeverity.VERY_POOR_HOTSPOT
                else:
                    severity = HotspotSeverity.ELEVATED_CLUSTER

                chain_note = (
                    " Note: Multi-station spatial cluster bounds reflect network chain connectivity "
                    "and do not imply uniform pollution levels throughout the geographic bounding area."
                    if cluster_radius > 10.0
                    else ""
                )

                explanation = (
                    f"Confirmed spatial pollution cluster verified by {count} distinct monitoring stations "
                    f"({physical_count} physical monitors) ({', '.join(station_names[:3])}{'...' if count > 3 else ''}) "
                    f"spanning {cluster_radius:.1f} km. "
                    f"Peak observed AQI is {peak_aqi or 'N/A'} (mean: {mean_aqi or 'N/A'}) driven by {dominant_pol}.{chain_note}"
                )
            else:
                is_confirmed = False
                severity = HotspotSeverity.ISOLATED_ELEVATED_READING
                explanation = (
                    f"Single isolated elevated reading (AQI {peak_aqi or 'N/A'}) observed at {station_names[0]}. "
                    f"Not classified as a confirmed geographic hotspot due to lack of multi-station spatial corroboration."
                )

            hotspot_items.append(
                HotspotCluster(
                    cluster_id=cluster_id,
                    center_location=LocationCoordinate(
                        latitude=centroid_lat,
                        longitude=centroid_lon,
                        city=cluster_members[0].location.city or "Cluster Area",
                        country="India",
                    ),
                    radius_km=cluster_radius,
                    severity=severity,
                    contributing_stations_count=count,
                    physical_stations_count=physical_count,
                    is_confirmed_hotspot=is_confirmed,
                    peak_aqi=peak_aqi,
                    mean_aqi=mean_aqi,
                    peak_pm2_5=peak_pm25,
                    dominant_pollutant=dominant_pol,
                    data_source_type=provenance,
                    contributing_stations=station_ids,
                    explanation=explanation,
                    detected_at=now_utc,
                )
            )

        # Sort hotspots: confirmed first, then by peak_aqi descending
        hotspot_items.sort(
            key=lambda h: (1 if h.is_confirmed_hotspot else 0, h.peak_aqi or 0),
            reverse=True,
        )

        return GeoHotspotsResponse(
            center_location=center_coord,
            query_radius_km=query_radius_km,
            hotspots=hotspot_items,
            total_hotspots_count=len(hotspot_items),
            timestamp=now_utc,
        )


# Singleton instance
hotspot_service = HotspotDetectionService()
