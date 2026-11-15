"""
AirGuard AI - Unit Tests for Provider Adapters
Validates provider adapters with mocked external HTTP responses.
Ensures tests do not depend on external API availability or networks.
"""
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch
import pytest
import httpx

from app.providers.openaq_provider import OpenAQProvider
from app.providers.open_meteo_provider import OpenMeteoProvider
from app.providers.cpcb_provider import CPCBDataGovProvider
from app.providers.demo_provider import DemoFixtureProvider
from app.schemas.pollutant import DataSourceType
from app.schemas.provider import ProviderHealth


@pytest.mark.asyncio
async def test_openaq_unauthenticated_status():
    """When OPENAQ_API_KEY is unset, provider reports UNAUTHENTICATED gracefully."""
    provider = OpenAQProvider()
    with patch("app.providers.openaq_provider.settings.OPENAQ_API_KEY", None):
        status = await provider.check_health()
        assert status.status == ProviderHealth.UNAUTHENTICATED
        assert status.is_authenticated is False
        assert "OPENAQ_API_KEY" in status.details


@pytest.mark.asyncio
async def test_openaq_authenticated_mock_health():
    """When API returns 200, provider reports ONLINE."""
    provider = OpenAQProvider()
    with patch("app.providers.openaq_provider.settings.OPENAQ_API_KEY", "test_key_123"):
        mock_response = httpx.Response(200, json={"results": [{"id": 1}]}, request=httpx.Request("GET", "http://test"))
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_response):
            status = await provider.check_health()
            assert status.status == ProviderHealth.ONLINE
            assert status.is_authenticated is True


@pytest.mark.asyncio
async def test_openaq_rate_limited_mock():
    """When API returns 429, provider reports DEGRADED."""
    provider = OpenAQProvider()
    with patch("app.providers.openaq_provider.settings.OPENAQ_API_KEY", "test_key_123"):
        mock_response = httpx.Response(429, json={"message": "Too Many Requests"}, request=httpx.Request("GET", "http://test"))
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_response):
            status = await provider.check_health()
            assert status.status == ProviderHealth.DEGRADED
            assert "Rate limit" in status.details


@pytest.mark.asyncio
async def test_openaq_nearby_stations_mock():
    """Verify nearby station parsing from OpenAQ v3 response."""
    provider = OpenAQProvider()
    mock_payload = {
        "results": [
            {
                "id": 8118,
                "name": "Delhi US Embassy",
                "coordinates": {"latitude": 28.598, "longitude": 77.189},
                "locality": "New Delhi",
                "country": {"name": "India"},
                "sensors": [
                    {"parameter": {"name": "pm25"}},
                    {"parameter": {"name": "pm10"}},
                    {"parameter": {"name": "no2"}},
                ],
                "datetimeLast": {"utc": "2026-11-15T10:00:00Z"},
            }
        ]
    }
    with patch("app.providers.openaq_provider.settings.OPENAQ_API_KEY", "test_key"):
        mock_response = httpx.Response(200, json=mock_payload, request=httpx.Request("GET", "http://test"))
        with patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_response):
            stations = await provider.get_nearby_stations(28.6139, 77.2090, 25.0)
            assert len(stations) == 1
            st = stations[0]
            assert st.station_id == "OPENAQ-8118"
            assert st.station_name == "Delhi US Embassy"
            assert st.data_source_type == DataSourceType.LIVE
            assert "PM2.5" in st.available_pollutants
            assert st.distance_km is not None


@pytest.mark.asyncio
async def test_open_meteo_current_observation_mock():
    """Verify Open-Meteo model conversion and ESTIMATED classification."""
    provider = OpenMeteoProvider()
    air_payload = {
        "current": {
            "time": "2026-11-15T12:00",
            "pm10": 140.5,
            "pm2_5": 85.2,
            "carbon_monoxide": 2200.0,  # µg/m³ -> 2.2 mg/m³
            "nitrogen_dioxide": 45.0,
            "sulphur_dioxide": 12.0,
            "ozone": 30.0,
        }
    }
    mock_res = httpx.Response(200, json=air_payload, request=httpx.Request("GET", "http://test"))
    with patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_res):
        obs = await provider.get_current_observation(latitude=28.6139, longitude=77.2090)
        assert obs is not None
        assert obs.data_source_type == DataSourceType.ESTIMATED
        assert obs.pm2_5 == 85.2
        assert obs.pm10 == 140.5
        assert obs.co == 2.2  # correctly converted from µg/m³ to mg/m³
        assert obs.no2 == 45.0


@pytest.mark.asyncio
async def test_cpcb_unauthenticated_status():
    """CPCB data.gov.in reports UNAUTHENTICATED without key."""
    provider = CPCBDataGovProvider()
    with patch("app.providers.cpcb_provider.settings.DATAGOVIN_API_KEY", None):
        status = await provider.check_health()
        assert status.status == ProviderHealth.UNAUTHENTICATED
        assert "DATAGOVIN_API_KEY" in status.details


@pytest.mark.asyncio
async def test_demo_fixture_provider():
    """Demo fixtures provider returns properly labeled DEMO_FIXTURE stations."""
    provider = DemoFixtureProvider()
    stations = await provider.get_nearby_stations(28.6, 77.2, radius_km=50.0)
    assert len(stations) >= 1
    assert all(s.data_source_type == DataSourceType.DEMO_FIXTURE for s in stations)

    obs = await provider.get_current_observation(station_id="DEMO-DELHI-001")
    assert obs is not None
    assert obs.data_source_type == DataSourceType.DEMO_FIXTURE
    assert "DEMO FIXTURE" in obs.station_name
