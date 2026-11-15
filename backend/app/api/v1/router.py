"""
AirGuard AI - API v1 Router Aggregator
"""
from fastapi import APIRouter
from app.api.v1.endpoints import aqi, health

api_router = APIRouter()

api_router.include_router(health.router, tags=["Health"])
api_router.include_router(aqi.router, prefix="/aqi", tags=["Environmental Intelligence & AQI"])
