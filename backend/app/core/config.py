"""
AirGuard AI - Core Configuration
"""
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "AirGuard AI"
    VERSION: str = "1.2.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # CORS settings
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "*",
    ]

    # Database
    DATABASE_URL: str = "sqlite:///./airguard.db"

    # AQI Data Stale Threshold in minutes (CPCB / general threshold)
    DATA_STALE_THRESHOLD_MINUTES: int = 120

    # Provider Configurations
    # 1. OpenAQ API v3 (https://docs.openaq.org/)
    OPENAQ_API_KEY: Optional[str] = None
    OPENAQ_BASE_URL: str = "https://api.openaq.org/v3"

    # 2. Open-Meteo Air Quality API (free, model-derived)
    OPEN_METEO_AIR_BASE_URL: str = "https://air-quality-api.open-meteo.com/v1"
    OPEN_METEO_WEATHER_BASE_URL: str = "https://api.open-meteo.com/v1"

    # 3. CPCB / data.gov.in (requires registered API key from data.gov.in)
    DATAGOVIN_API_KEY: Optional[str] = None
    DATAGOVIN_BASE_URL: str = "https://api.data.gov.in/resource"
    DATAGOVIN_RESOURCE_ID: str = "3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69"

    # 4. LLM Explainer Configurations (Backend-only credentials)
    GEMINI_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None

    # Caching and Rate-limiting TTLs
    CACHE_STATIONS_TTL_SECONDS: int = 3600      # 1 hour
    CACHE_OBSERVATIONS_TTL_SECONDS: int = 900   # 15 minutes
    CACHE_PROVIDER_STATUS_TTL_SECONDS: int = 300 # 5 minutes
    CACHE_FORECAST_TTL_SECONDS: int = 900       # 15 minutes
    CACHE_EXPLANATION_TTL_SECONDS: int = 1800   # 30 minutes

    # Default Search Parameters
    DEFAULT_SEARCH_RADIUS_KM: float = 25.0
    MAX_SEARCH_RADIUS_KM: float = 100.0

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
