"""
AirGuard AI - Unit Tests for Geospatial Services
"""
import pytest
from app.services.geo import haversine_distance_km, get_bounding_box


def test_haversine_distance_same_point():
    """Distance between identical coordinates is 0.0 km."""
    d = haversine_distance_km(28.6139, 77.2090, 28.6139, 77.2090)
    assert d == 0.0


def test_haversine_distance_delhi_to_mumbai():
    """Approximate distance between New Delhi and Mumbai is ~1150-1160 km."""
    # New Delhi: 28.6139, 77.2090
    # Mumbai: 19.0760, 72.8777
    d = haversine_distance_km(28.6139, 77.2090, 19.0760, 72.8777)
    assert 1140.0 < d < 1180.0


def test_haversine_short_distance():
    """Anand Vihar to Connaught Place is approx 11-14 km."""
    # Anand Vihar: 28.6508, 77.3152
    # Connaught Place: 28.6315, 77.2167
    d = haversine_distance_km(28.6508, 77.3152, 28.6315, 77.2167)
    assert 9.0 < d < 15.0


def test_bounding_box_generation():
    """Verify calculated bounding box encapsulates center with expected delta."""
    min_lat, min_lon, max_lat, max_lon = get_bounding_box(28.6139, 77.2090, radius_km=25.0)
    assert min_lat < 28.6139 < max_lat
    assert min_lon < 77.2090 < max_lon
    # Latitude delta for 25km should be ~0.22 degrees
    assert abs((max_lat - 28.6139) - 0.226) < 0.05
