"""
AirGuard AI - Backend Application Entrypoint
FastAPI-powered environmental intelligence platform.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.api.v1.router import api_router
from app.db.base import Base, engine
import app.db.models  # ensure models are registered


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database tables
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=(
        "AIRGUARD AI is an environmental intelligence platform providing deterministic "
        "CPCB National Air Quality Index (IND-AQI) calculations, explainable exposure risk scoring, "
        "and grounded environmental health advisories."
    ),
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount API routers
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Root"])
async def root():
    return JSONResponse(
        content={
            "app": settings.PROJECT_NAME,
            "version": settings.VERSION,
            "status": "operational",
            "docs": f"{settings.API_V1_STR}/docs",
            "specification": "CPCB IND-AQI (2014 Standard)",
        }
    )
