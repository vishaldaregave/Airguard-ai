"""
AirGuard AI - Geospatial Intelligence Services
Implements precise Haversine distance calculations and coordinate utilities.
"""
import math
from typing import Tuple


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on the Earth (specified in decimal degrees).
    Returns distance in kilometers rounded to 2 decimal places.
    """
    # Earth radius in kilometers
    R = 6371.0

    # Convert decimal degrees to radians
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    # Haversine formula
    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    # Bounded to [0, 1] to avoid float precision issues with asin/atan2
    a = min(1.0, max(0.0, a))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    distance = R * c
    return round(distance, 2)


def get_bounding_box(lat: float, lon: float, radius_km: float) -> Tuple[float, float, float, float]:
    """
    Calculates a bounding box (min_lat, min_lon, max_lat, max_lon)
    around a center point for a given radius in kilometers.
    """
    # Latitude: 1 deg ~ 110.574 km
    lat_delta = radius_km / 110.574
    min_lat = max(-90.0, lat - lat_delta)
    max_lat = min(90.0, lat + lat_delta)

    # Longitude: 1 deg ~ 111.320 * cos(lat) km
    cos_lat = math.cos(math.radians(lat))
    if cos_lat < 1e-6:
        lon_delta = 180.0
    else:
        lon_delta = radius_km / (111.320 * cos_lat)

    min_lon = max(-180.0, lon - lon_delta)
    max_lon = min(180.0, lon + lon_delta)

    return (round(min_lat, 6), round(min_lon, 6), round(max_lat, 6), round(max_lon, 6))
