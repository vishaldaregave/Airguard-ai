"""
AirGuard AI - Forecasting Data Contracts and Schemas
Strict scientific modeling: prediction intervals, multi-horizon horizons, and forecast CPCB AQI.
"""
from enum import Enum
from typing import Dict, List, Optional, Tuple
from datetime import datetime
from pydantic import BaseModel, Field

from app.schemas.pollutant import DataSourceType, LocationCoordinate, PollutantType
from app.schemas.aqi import AQICategory, CalculationStatus, SubIndexResult


class ForecastHorizonHours(int, Enum):
    ONE_HOUR = 1
    THREE_HOURS = 3
    SIX_HOURS = 6
    TWELVE_HOURS = 12
    TWENTY_FOUR_HOURS = 24


class ModelType(str, Enum):
    AUTOREGRESSIVE_RIDGE = "AUTOREGRESSIVE_RIDGE"
    SEASONAL_NAIVE = "SEASONAL_NAIVE"
    PERSISTENCE_BASELINE = "PERSISTENCE_BASELINE"


class PollutantPrediction(BaseModel):
    pollutant: str = Field(..., description="Pollutant identifier (PM2.5, PM10, etc.)")
    unit: str = Field(..., description="Measurement unit (µg/m³ or mg/m³ for CO)")
    point_estimate: float = Field(..., description="Central point forecast value")
    interval_90: Tuple[float, float] = Field(
        ..., description="Statistical 90% prediction interval [lower, upper] based on empirical residual variance"
    )
    interval_95: Tuple[float, float] = Field(
        ..., description="Statistical 95% prediction interval [lower, upper] based on empirical residual variance"
    )
    trend: str = Field("STABLE", description="Predicted short-term trajectory: RISING, FALLING, or STABLE")


class HorizonForecastStep(BaseModel):
    horizon_hours: int = Field(..., description="Prediction horizon offset in hours (1, 3, 6, 12, 24)")
    target_timestamp: datetime = Field(..., description="Future target time in ISO 8601 UTC format")
    data_source_type: DataSourceType = Field(DataSourceType.FORECAST, description="Always FORECAST")
    
    # Individual pollutant point predictions and prediction intervals
    predictions: Dict[str, PollutantPrediction] = Field(
        default_factory=dict, description="Pollutant predictions with statistical intervals"
    )
    
    # Deterministic CPCB Forecast AQI outcome
    forecast_aqi: Optional[int] = Field(None, description="Forecast CPCB AQI (maximum valid predicted sub-index)")
    forecast_category: Optional[AQICategory] = Field(None, description="CPCB health risk category for forecast")
    forecast_color_code: Optional[str] = Field(None, description="Category hex color code")
    prominent_pollutant: Optional[str] = Field(None, description="Pollutant driving the forecast AQI")
    cpcb_status: CalculationStatus = Field(..., description="Status of CPCB 3-pollutant / PM criteria enforcement")
    cpcb_status_message: str = Field(..., description="Explanation of calculation validation")


class ForecastModelMetadata(BaseModel):
    model_id: str = Field(..., description="Model identifier and release version")
    model_type: ModelType = Field(..., description="Architecture type (e.g. AUTOREGRESSIVE_RIDGE)")
    training_sample_count: int = Field(..., description="Total training instances used in model calibration")
    features_used: List[str] = Field(default_factory=list, description="Explanatory and meteorological features")
    last_trained_timestamp: datetime = Field(..., description="Timestamp of most recent model training cycle")
    status: str = Field("OPERATIONAL", description="Model lifecycle status: OPERATIONAL, INSUFFICIENT_DATA, etc.")


class ForecastCurrentResponse(BaseModel):
    station_id: str = Field(..., description="Station or regional grid identifier")
    station_name: str = Field(..., description="Station display name")
    location: LocationCoordinate = Field(..., description="Station coordinates")
    forecast_generated_at: datetime = Field(..., description="Generation timestamp in UTC")
    model_metadata: ForecastModelMetadata = Field(..., description="Forecasting model provenance")
    horizons: List[HorizonForecastStep] = Field(..., description="Forecast steps for 1h, 3h, 6h, 12h, and 24h")


class HorizonMetricComparison(BaseModel):
    horizon_hours: int = Field(..., description="Horizon offset in hours")
    pollutant: str = Field(..., description="Target pollutant")
    test_sample_count: int = Field(..., description="Number of out-of-sample evaluation steps")
    model_mae: float = Field(..., description="Model Mean Absolute Error")
    model_rmse: float = Field(..., description="Model Root Mean Squared Error")
    persistence_mae: float = Field(..., description="Persistence Baseline MAE")
    persistence_rmse: float = Field(..., description="Persistence Baseline RMSE")
    seasonal_naive_mae: float = Field(..., description="Seasonal Naive (24h diurnal) MAE")
    seasonal_naive_rmse: float = Field(..., description="Seasonal Naive (24h diurnal) RMSE")
    improvement_vs_persistence_pct: float = Field(..., description="% error reduction relative to persistence")


class ForecastAccuracyResponse(BaseModel):
    model_id: str = Field(..., description="Evaluated model identifier")
    evaluation_dataset_duration_days: float = Field(..., description="Evaluation time span in days")
    metrics: List[HorizonMetricComparison] = Field(..., description="Evaluation metrics across horizons and pollutants")
    summary: str = Field(..., description="Summary of forecast performance vs baselines")
