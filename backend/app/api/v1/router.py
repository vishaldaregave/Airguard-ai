"""
AirGuard AI - API v1 Router Aggregator
"""
from fastapi import APIRouter
from app.api.v1.endpoints import aqi, health, locations, stations, air, forecast, ai, history

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(aqi.router, prefix="/aqi", tags=["CPCB AQI & Calculation"])
api_router.include_router(locations.router, prefix="/locations", tags=["Location Intelligence"])
api_router.include_router(stations.router, prefix="/stations", tags=["Monitoring Stations"])
api_router.include_router(air.router, prefix="/air", tags=["Live Air Quality & Providers"])
api_router.include_router(forecast.router, prefix="/forecast", tags=["Air Quality Forecasting"])
api_router.include_router(ai.router, prefix="/ai", tags=["AI Environmental Explanations"])
api_router.include_router(history.router, prefix="/history", tags=["Historical Data Foundation"])
