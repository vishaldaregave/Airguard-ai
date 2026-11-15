# AIRGUARD AI — SYSTEM ARCHITECTURE

## 1. Architectural Philosophy
AirGuard AI is engineered as a software-only, production-grade environmental intelligence platform for Android and cloud backends. It strictly adheres to:
- **Clean Architecture & Separation of Concerns**: Clear boundary between presentation, domain, data access, deterministic environmental calculation engines, multi-provider pipelines, time-series forecasting, and explainable AI analytics.
- **Uncompromised Data Integrity**: Real readings are distinguished from estimates, forecasts, or demo fixtures. Missing measurements are never treated as zero.
- **Deterministic AI & Grounded Explanations**: Official CPCB AQI calculations rely strictly on verified formulas. AI explanations interpret verified observations without calculating AQI or generating medical claims.
- **Scientifically Defensible Forecasting**: Multi-horizon predictions (+1h, +3h, +6h, +12h, +24h) are benchmarked against Persistence and Seasonal Naive baselines, trained strictly chronologically (no future data leakage), and accompanied by empirical prediction intervals.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AirGuard AI Flutter App                         │
│   (Material 3 Dark Futuristic • Riverpod • GoRouter • FL Chart)        │
└──────────────────────────────────┬─────────────────────────────────────┘
                                    │ Typed REST JSON Contracts
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        FastAPI Backend Service                         │
│  (Pydantic v2 • SQLAlchemy 2.0 • OpenAPI Specification • In-Memory TTL)│
├──────────────────────────────────┬─────────────────────────────────────┤
│ Deterministic CPCB AQI Engine    │ Multi-Horizon Forecasting Engine    │
│ • Linear Interpolation           │ • Autoregressive Ridge Regression   │
│ • Minimum 3-Pollutant Rule       │ • Diurnal Harmonics (sin/cos)       │
│ • Particulate Matter Check       │ • Meteorological Coupling           │
│ • Prominent Driver Logic         │ • Empirical Prediction Intervals    │
├──────────────────────────────────┼─────────────────────────────────────┤
│ Grounded AI Explainer Layer      │ Explainable Risk Engine             │
│ • Gemini 1.5 Flash / REST        │ • Synergistic Compounding           │
│ • Deterministic Fallback Engine  │ • Atmospheric Stagnation Index      │
│ • 6 Core Atmospheric Dimensions  │ • Grounded Activity Recommendations │
├──────────────────────────────────┴─────────────────────────────────────┤
│               Multi-Provider Environmental Pipeline                    │
│ • Geospatial Intelligence (Haversine & Radius Discovery)               │
│ • Data Quality Engine (25°C Ref Unit Normalization, Outlier Rejection) │
│ • Provider-Calibrated Freshness & Deduplication                        │
│ • Persistent Historical Archive (StationObservations & ForecastRecords)│
└──────┬───────────────────────────┬───────────────────────────┬─────────┘
       │                           │                           │
       ▼                           ▼                           ▼
┌───────────────┐          ┌────────────────┐          ┌──────────────────┐
│  OpenAQ v3    │          │   Open-Meteo   │          │ CPCB data.gov.in │
│ (Ground LIVE) │          │ (Model ESTIM.) │          │  (National NAMP) │
└───────────────┘          └────────────────┘          └──────────────────┘
```

## 2. Frontend Layer (Flutter / Dart)
- **State Management**: Flutter Riverpod (`StateNotifierProvider`, immutable states).
- **Navigation**: GoRouter for deep linking and screen transitions.
- **Charts & Telemetry**: FL Chart for interactive time-series AQI trends with 95% uncertainty ribbons and horizon selection (+1h, +3h, +6h, +12h, +24h).
- **Design Tokens**: Material 3 dark futuristic aesthetic (`#090D16`, `#111827`, `#00E5A3`, `#00D2FF`, `#8B5CF6`).

## 3. Persistent Historical Foundation (SQLite / SQLAlchemy)
- Stores observation records across physical stations, model estimates, and synthetic fixtures with explicit provenance tags (`DATA_SOURCE_TYPE`).
- Captures pollutant concentrations (PM2.5, PM10, NO2, SO2, CO, O3, NH3), units, averaging periods, quality flags, and meteorological variables (temperature, relative humidity, wind speed, wind direction, surface pressure, precipitation).
- Dedicated availability audit endpoint (`/history/availability`) verifies record counts, duration, and data integrity.

## 4. Multi-Horizon Time-Series Forecasting Pipeline
- **Horizons**: +1h, +3h, +6h, +12h, +24h.
- **Model**: Multi-Output Autoregressive Ridge Regression with Closed-Form L2 Regularization ($W = (X^T X + \alpha I)^{-1} X^T y$).
- **Features**: Lagged pollutant series ($t, t-1, t-2, t-3$), diurnal harmonic cycles ($\sin(2\pi \cdot hour/24), \cos(2\pi \cdot hour/24)$), and meteorological features ($T, RH, Wind$).
- **Validation**: Strict chronological split (first 70% train, next 15% validation, final 15% test). Absolutely no shuffling or future data leakage.
- **Uncertainty Quantification**: Empirical residual standard error from out-of-fold validation ($\sigma_h = \sqrt{\frac{1}{N}\sum (y - \hat{y})^2}$). Computes 90% ($z=1.645$) and 95% ($z=1.960$) prediction intervals with non-negative physical clamping and monotonic horizon expansion.
- **CPCB Forecast AQI**: Evaluated strictly through the deterministic CPCB engine for each forecast horizon. If fewer than 3 pollutants or no particulate matter is available, returns `is_cpcb_aqi_valid: false` without inventing values.

## 5. Grounded AI Atmospheric Explainer
- **Abstraction**: `BaseLLMClient` with implementations for `GeminiLLMClient` and `DeterministicRuleBasedExplainer`.
- **Security**: Zero API keys on mobile clients. All keys are managed exclusively on the backend (`GEMINI_API_KEY`).
- **Resilience**: If the LLM provider fails, times out, or has no API key configured, automatically falls back to the deterministic expert engine with zero downtime.
- **Dimensions Addressed**:
  1. Atmospheric dynamics & boundary layer stability.
  2. Primary driver & sub-index contribution.
  3. Meteorological stagnation & dispersion influences.
  4. Outdoor activity implications.
  5. Practical non-clinical precautions.
  6. Historical baseline comparison.
- **Strict Compliance**: Zero hallucinations, never calculates AQI inside LLM, never invents missing parameters, includes non-medical disclaimer.
