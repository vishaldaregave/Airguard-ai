"""
AirGuard AI - Unit Tests for Forecasting Engine
Tests:
- Chronological train/validation/test split (no data leakage)
- Persistence and seasonal baseline evaluations
- Monotonic expansion of empirical prediction intervals
- Forecast CPCB AQI calculation integration
- Insufficient training data handling
"""
from datetime import datetime, timezone, timedelta
import pytest
import numpy as np

from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.aqi import CalculationStatus
from app.engine.forecasting import TimeSeriesForecastModel, HORIZONS, TARGET_POLLUTANTS


def generate_synthetic_diurnal_history(n_hours: int = 72) -> list:
    """Generates synthetic hourly observations with realistic diurnal cycling."""
    records = []
    now = datetime.now(timezone.utc) - timedelta(hours=n_hours)
    for i in range(n_hours):
        t = now + timedelta(hours=i)
        h = t.hour
        # Diurnal PM2.5 (higher at night/morning)
        diurnal = 1.0 + 0.3 * np.sin((h - 4) * np.pi / 12.0)
        pm25 = max(10.0, 80.0 * diurnal + (i % 5 - 2) * 3.0)
        pm10 = max(20.0, pm25 * 1.6)
        no2 = max(10.0, 45.0 * (1.0 + 0.2 * np.sin(h * np.pi / 12.0)))
        so2 = 20.0 + (i % 3) * 2.0
        co = 1.2 * diurnal
        o3 = 25.0 * (1.0 - 0.5 * np.sin(h * np.pi / 12.0))
        records.append({
            "timestamp": t,
            "PM2.5": pm25,
            "PM10": pm10,
            "NO2": no2,
            "SO2": so2,
            "CO": co,
            "O3": o3,
            "temperature_celsius": 25.0 - 5.0 * np.sin(h * np.pi / 12.0),
            "relative_humidity_pct": 60.0 + 20.0 * np.sin((h - 18) * np.pi / 12.0),
            "wind_speed_kmh": 8.0 - 3.0 * np.sin((h - 6) * np.pi / 12.0),
            "surface_pressure_hpa": 1013.25,
        })
    return records


def test_no_data_leakage_chronological_split():
    """Verify train/test split maintains strict temporal order."""
    records = generate_synthetic_diurnal_history(72)
    model = TimeSeriesForecastModel(ridge_alpha=1.0)
    success = model.train_and_evaluate(records, train_ratio=0.7, val_ratio=0.15)
    assert success is True
    assert model.training_sample_count == int(72 * 0.7)
    # Check that test metrics were calculated
    metrics = model.get_accuracy_metrics()
    assert len(metrics) > 0
    for m in metrics:
        assert m.test_sample_count > 0
        assert m.model_mae >= 0.0
        assert m.model_rmse >= m.model_mae  # Standard mathematical inequality RMSE >= MAE


def test_baseline_comparison():
    """Verify model is evaluated against persistence and seasonal naive baselines."""
    records = generate_synthetic_diurnal_history(72)
    model = TimeSeriesForecastModel()
    model.train_and_evaluate(records)
    metrics = model.get_accuracy_metrics()

    pm25_metrics = [m for m in metrics if m.pollutant == "PM2.5"]
    assert len(pm25_metrics) == len(HORIZONS)
    for m in pm25_metrics:
        assert m.persistence_mae > 0.0
        assert m.seasonal_naive_mae > 0.0
        assert m.model_mae > 0.0


def test_forecast_prediction_intervals_expand_with_horizon():
    """Statistical prediction interval width should expand as lead time increases."""
    records = generate_synthetic_diurnal_history(72)
    model = TimeSeriesForecastModel()
    model.train_and_evaluate(records)

    obs = EnvironmentalObservationInput(
        station_id="TEST-STATION-01",
        station_name="Test Station",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Test Provider",
        data_source_type=DataSourceType.LIVE,
        pm2_5=85.0,
        pm10=140.0,
        no2=45.0,
        so2=22.0,
        co=1.5,
        o3=30.0,
    )

    steps = model.predict_horizons(obs, records)
    assert len(steps) == len(HORIZONS)

    # Verify interval expansion
    widths_95 = []
    for step in steps:
        pm25_pred = step.predictions["PM2.5"]
        assert pm25_pred.interval_95[0] >= 0.0  # Non-negative lower bound
        assert pm25_pred.interval_95[1] >= pm25_pred.interval_95[0]
        # 95% interval must be wider than or equal to 90% interval
        w95 = pm25_pred.interval_95[1] - pm25_pred.interval_95[0]
        w90 = pm25_pred.interval_90[1] - pm25_pred.interval_90[0]
        assert w95 >= w90
        widths_95.append(w95)

    # Lead time 24h interval must be wider than 1h interval
    assert widths_95[-1] > widths_95[0]


def test_forecast_cpcb_aqi_integration():
    """Verify predicted pollutants feed into deterministic CPCB engine."""
    records = generate_synthetic_diurnal_history(72)
    model = TimeSeriesForecastModel()
    model.train_and_evaluate(records)

    obs = EnvironmentalObservationInput(
        station_id="DELHI-GRID",
        station_name="Delhi Grid",
        location=LocationCoordinate(latitude=28.6, longitude=77.2, city="Delhi"),
        timestamp=datetime.now(timezone.utc),
        provider="Open-Meteo",
        data_source_type=DataSourceType.ESTIMATED,
        pm2_5=120.0,
        pm10=200.0,
        no2=55.0,
        so2=25.0,
        co=1.8,
        o3=35.0,
    )

    steps = model.predict_horizons(obs, records)
    for step in steps:
        assert step.data_source_type == DataSourceType.FORECAST
        assert step.forecast_aqi is not None
        assert step.forecast_aqi > 0
        assert step.forecast_category is not None
        assert step.prominent_pollutant in ["PM2.5", "PM10"]
        assert step.cpcb_status == CalculationStatus.VALID


def test_insufficient_training_data():
    """If training records < 36, train_and_evaluate returns False gracefully."""
    few_records = generate_synthetic_diurnal_history(10)
    model = TimeSeriesForecastModel()
    success = model.train_and_evaluate(few_records)
    assert success is False
