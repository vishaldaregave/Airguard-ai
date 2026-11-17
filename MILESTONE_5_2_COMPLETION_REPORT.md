# AIRGUARD AI — MILESTONE 5.2 COMPLETION REPORT
## Exposure Simulator & Personal Environmental Exposure Intelligence

**Repository:** `D:\Development\Airgaurd-ai`  
**Milestone:** 5.2 — Exposure Simulator & Personal Environmental Exposure Intelligence  
**Previous Baseline Commit:** `581045d` (Milestone 5.1.1 Spatial Accuracy & Geographic Validation Audit)  
**Date:** November 17, 2026  
**Status:** Complete, Verified, Zero Regressions  

---

## 1. Executive Summary

Milestone 5.2 establishes a deterministic, mathematically transparent **Exposure Simulator** and **Personal Environmental Exposure Intelligence** engine within the AIRGUARD AI platform. 

The simulator quantifies cumulative pollutant exposure over user-configurable activity sessions ($15$ to $480$ minutes) across standard criteria pollutants ($\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{NO}_2$, $\text{SO}_2$, $\text{CO}$, $\text{O}_3$). It integrates physical station observations, inverse distance weighted (IDW) spatial interpolations, chronological forecast horizons ($+1\text{h}$, $+3\text{h}$, $+6\text{h}$), and interactive what-if parameters.

Crucially, this system enforces rigorous **scientific reporting integrity**:
- **Pure Physical Modeling**: Calculations evaluate concentration-time exposure and gross inhaled air/pollutant mass based on verified physiological ventilation benchmarks from the **US EPA Exposure Factors Handbook (2011)**.
- **Strict Clinical Boundary**: Estimates are explicitly bounded as non-clinical physical intake approximations. The engine never claims internal biological absorption, tissue deposition fractions, or medical diagnoses.
- **Pollutant Separation**: Criteria pollutants are calculated independently with explicit physical units ($\mu\text{g}\cdot\text{h/m}^3$ and $\mu\text{g}$ for particulates/trace gases; $\text{mg}\cdot\text{h/m}^3$ and $\text{mg}$ for carbon monoxide). Criteria pollutants are never summed into an unscientific aggregate exposure score.
- **Integrity of Missing Data**: Incomplete pollutant readings are strictly preserved as unavailable/`None` rather than silently coerced to zero.
- **Scenario Comparison**: Users can contrast baseline vs alternative activities, locations, or durations to observe physical intake deltas ($\Delta \text{Mass}$, $\% \Delta$) without misleading safety claims.

---

## 2. Architecture & Files Changed

```
Airgaurd-ai/
+-- backend/
¦   +-- app/
¦   ¦   +-- api/v1/
¦   ¦   ¦   +-- endpoints/
¦   ¦   ¦   ¦   +-- exposure.py                       # [NEW] FastAPI router under /api/v1/exposure/
¦   ¦   ¦   +-- router.py                             # [MODIFIED] Registered exposure router
¦   ¦   +-- engine/
¦   ¦   ¦   +-- exposure_engine.py                    # [NEW] Pure deterministic calculation engine & EPA profiles
¦   ¦   +-- schemas/
¦   ¦   ¦   +-- exposure.py                           # [NEW] Pydantic contracts & validation schemas
¦   ¦   +-- services/
¦   ¦       +-- exposure_service.py                   # [NEW] Orchestration for observations, forecasts, IDW & AI explainer
¦   +-- tests/
¦       +-- test_exposure_simulator.py                # [NEW] Pytest suite (10 comprehensive tests)
+-- frontend/
¦   +-- lib/
¦   ¦   +-- core/
¦   ¦   ¦   +-- constants/
¦   ¦   ¦   ¦   +-- api_constants.dart                # [MODIFIED] API route definitions for exposure
¦   ¦   ¦   +-- router/
¦   ¦   ¦       +-- app_router.dart                   # [MODIFIED] GoRouter path '/exposure'
¦   ¦   +-- features/
¦   ¦       +-- environmental_intelligence/
¦   ¦           +-- data/
¦   ¦           ¦   +-- repositories/
¦   ¦           ¦       +-- environmental_repository.dart # [MODIFIED] Exposure API calls + offline fallbacks
¦   ¦           +-- domain/
¦   ¦           ¦   +-- models/
¦   ¦           ¦       +-- exposure_models.dart      # [NEW] Riverpod/Dart immutable domain models
¦   ¦           +-- presentation/
¦   ¦               +-- controllers/
¦   ¦               ¦   +-- exposure_controller.dart  # [NEW] StateNotifier for simulator state & scenarios
¦   ¦               +-- screens/
¦   ¦                   +-- dashboard_screen.dart     # [MODIFIED] Exposure Simulator launcher card & app bar action
¦   ¦                   +-- exposure_simulator_screen.dart # [NEW] Dark Material 3 interactive simulator UI
¦   +-- test/
¦       +-- exposure_flow_test.dart                   # [NEW] Flutter widget & serialization tests (6 tests)
¦       +-- geo_canvas_validation_test.dart           # [MODIFIED] Cleaned unused import
```

---

## 3. Mathematical Engine & Calculation Methodology

### 3.1. Concentration-Time Exposure

For each criteria pollutant $p$:
$$\text{Exposure Index}_p = C_p \times t$$

Where:
- $C_p$ is the ambient pollutant concentration.
- $t$ is the duration in hours ($t = \frac{\text{duration\_minutes}}{60}$).
- **Units**:
  - Particulate matter ($\text{PM}_{2.5}, \text{PM}_{10}$) and trace gases ($\text{NO}_2, \text{SO}_2, \text{O}_3$): $\mu\text{g}\cdot\text{h/m}^3$.
  - Carbon monoxide ($\text{CO}$): $\text{mg}\cdot\text{h/m}^3$.

### 3.2. Total Inhaled Air Volume & Estimated Inhaled Mass

Using standardized adult minute ventilation rates ($V_E$ in $\text{m}^3/\text{h}$):
$$V_{\text{inhaled}} = V_E \times t \quad [\text{m}^3]$$
$$\text{Estimated Inhaled Mass}_p = C_p \times V_E \times t \quad [\mu\text{g} \text{ or } \text{mg}]$$

Where:
- Particulates & trace gases: $\mu\text{g/m}^3 \times \text{m}^3 = \mu\text{g}$.
- Carbon monoxide: $\text{mg/m}^3 \times \text{m}^3 = \text{mg}$.

### 3.3. Scenario Comparison Engine

When comparing Scenario A (baseline) against Scenario B (alternative):
$$\Delta \text{Exposure}_p = \text{Exposure}_{p, B} - \text{Exposure}_{p, A}$$
$$\Delta \text{Inhaled Mass}_p = \text{Mass}_{p, B} - \text{Mass}_{p, A}$$
$$\%\Delta \text{Inhaled Mass}_p = \frac{\text{Mass}_{p, B} - \text{Mass}_{p, A}}{\text{Mass}_{p, A}} \times 100\%$$

---

## 4. Activity Profiles & Reference Sources

Activity inhalation rates are derived directly from the **US Environmental Protection Agency (EPA) Exposure Factors Handbook: 2011 Edition (EPA/600/R-09/052F), Chapter 6 — Inhalation Rates**:

| Activity Key | Display Name | Inhalation Rate ($V_E$) | MET Equivalent | EPA Reference Category | Typical Activity Context |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `resting` | Resting / Sedentary | $0.50\text{ m}^3/\text{h}$ | $1.0\text{ MET}$ | Table 6-1, Sedentary/Passive | Reclining, quiet sitting, passive desk work |
| `commuting` | Commuting / In-Transit | $0.60\text{ m}^3/\text{h}$ | $1.5\text{ MET}$ | Table 6-1, Light In-Vehicle | Seated vehicle transit, metro transit |
| `walking` | Walking (Moderate) | $1.20\text{ m}^3/\text{h}$ | $3.0\text{ MET}$ | Table 6-2, Moderate Activity | Level walking at 4.0–4.8 km/h |
| `cycling` | Cycling (Commuter) | $2.10\text{ m}^3/\text{h}$ | $6.0\text{ MET}$ | Table 6-2, Moderate/Vigorous | Commuter cycling at ~15–19 km/h |
| `running` | Running / Jogging | $2.80\text{ m}^3/\text{h}$ | $8.0\text{ MET}$ | Table 6-3, Vigorous Activity | Aerobic running/jogging at ~8–10 km/h |

---

## 5. Backend REST API Endpoints

All endpoints reside under `/api/v1/exposure/`:

### 5.1. `GET /api/v1/exposure/activity-profiles`
Returns the standardized activity profiles, inhalation rates ($V_E$), MET equivalents, and EPA citations.

### 5.2. `POST /api/v1/exposure/simulate`
Accepts `SimulateExposureRequest`:
- `duration_minutes`: Integer $[15, 480]$.
- `activity_type`: Enum (`resting`, `commuting`, `walking`, `cycling`, `running`).
- Ambient Source (one of):
  - `custom_concentrations`: What-if pollutant mapping.
  - `station_id`: Physical station identifier.
  - `latitude`, `longitude`: Incurs real-time inverse distance weighting (IDW) spatial interpolation.
- Forecast horizons: `forecast_horizon_hours` ($+1, +3, +6$).
- Rejects stale data ($>120$ minutes old for live physical monitors).

### 5.3. `POST /api/v1/exposure/compare`
Accepts `CompareExposureRequest` with `scenario_a` and `scenario_b`. Computes absolute and percentage deltas per pollutant and outputs physical comparative rationale.

### 5.4. `POST /api/v1/exposure/explain`
Accepts `ExposureExplanationRequest`. Generates structured explanatory takeaways and practical exposure-reduction options using a deterministic rule-based template engine (or LLM if configured), maintaining strict disclaimers.

---

## 6. Frontend Flutter Implementation

The UI was crafted to seamlessly harmonize with AIRGUARD AI's dark Material 3 design system (`AppColors.cardBackground`, `AppColors.cyanAccent`, `AppColors.aqiPoor`, `AppColors.textMuted`):
- **Dashboard Launcher**: Added an "Exposure Simulator" card on the main dashboard providing direct access alongside the map and alert center.
- **Physical Activity Selector**: Choice chips with iconography (bed, directions bus, directions walk, directions bike, directions run) and real-time ventilation rate indicators ($0.50$ to $2.80\text{ m}^3/\text{h}$).
- **Exposure Duration Controls**: Interactive slider from $15\text{m}$ to $480\text{m}$ ($8\text{h}$) with quick-preset chips ($15\text{m}$, $30\text{m}$, $1\text{h}$, $2\text{h}$, $4\text{h}$).
- **Dual Mode Support**: Standard Single Simulation Mode and Comparative Scenario Mode (Scenario A vs Scenario B).
- **Physical Pollutant Metrics**: Distinct metric tiles for Particulates ($\text{PM}_{2.5}, \text{PM}_{10}$) and Gases ($\text{NO}_2, \text{SO}_2, \text{CO}, \text{O}_3$), clearly displaying:
  - Ambient concentration ($C$)
  - Cumulative concentration-time exposure ($C \times t$)
  - Gross inhaled mass ($C \times V_E \times t$)
  - Unavailable badge for missing measurements
- **Methodology & Non-Clinical Disclosures**: Prominent expander detailing EPA references, ventilation rate assumptions, and a clear legal/scientific disclaimer stating that calculations do not represent absorbed biological dose.

---

## 7. Scientific & Data Limitations

1. **Gross Inhaled Mass vs Absorbed Dose**: The calculated pollutant mass represents the mass of pollutant contained in the gross volume of ambient air inspired into the mouth/nose. It does not account for upper respiratory tract filtering, tracheobronchial clearance, alveolar deposition fractions, lung diffusion capacity, or personal respiratory health (e.g., tidal volume variability, COPD, asthma).
2. **Ambient vs Micro-Environmental Exposure**: The simulator uses ambient outdoor monitoring observations or spatial model grids. Real personal exposure is heavily influenced by indoor filtration (HVAC, HEPA filters), vehicle cabin air re-circulation, building infiltration factors, and localized micro-sources (cooking, idling vehicles).
3. **Restricted Averaging Period Alignment**: Physical monitor readings reflect hourly or sub-hourly averages. Short activity durations ($15\text{m}$) assume uniform dispersion during that window.
4. **No Combined Toxicological Metric**: Different chemical species have distinct toxicodynamics and physiological target organs; therefore, AIRGUARD AI explicitly avoids aggregating separate pollutants into an arbitrary total exposure index.

---

## 8. Automated Verification & Test Results

### 8.1. Backend Pytest Execution
Command:
```powershell
.\venv\Scripts\pytest.exe tests/ -v
```
**Result: 123 PASSED out of 123 tests (100% pass rate in 58.54s)**
- `test_concentration_time_calculation`: PASSED
- `test_estimated_inhaled_mass_calculation`: PASSED
- `test_missing_pollutant_preserved_as_none_never_zero`: PASSED
- `test_invalid_negative_values_rejected`: PASSED
- `test_activity_profiles_completeness_and_references`: PASSED
- `test_api_get_activity_profiles`: PASSED
- `test_api_simulate_custom_concentrations`: PASSED
- `test_api_simulate_duration_boundary_validation`: PASSED
- `test_api_compare_scenarios`: PASSED
- `test_api_explain_exposure`: PASSED
- All existing tests (alert engine, security, spatial interpolation, LOSO validation, forecasting, quality normalization): PASSED

### 8.2. Frontend Flutter Test Execution
Command:
```powershell
C:\flutter\bin\flutter.bat test
```
**Result: 32 PASSED out of 32 tests (100% pass rate in 5.2s)**
- `ActivityProfileModel parses correctly from JSON`: PASSED
- `PollutantExposureMetricModel preserves null ambient concentrations`: PASSED
- `ExposureSimulationModel parses correctly with all metrics`: PASSED
- `ExposureComparisonModel parses deltas correctly`: PASSED
- `ExposureSimulatorScreen renders title, activity chips, duration controls, and action button`: PASSED
- `Tapping comparison mode icon toggles Scenario B card`: PASSED
- All existing tests (geo canvas validation, alert flow, geo flow, smoke test): PASSED

### 8.3. Static Analysis
Command:
```powershell
C:\flutter\bin\flutter.bat analyze
```
**Result:**
```
Analyzing frontend...
No issues found! (ran in 2.2s)
```

---

## 9. Conclusion

Milestone 5.2 has been implemented with complete fidelity to the AIRGUARD AI specification. All mathematical formulas, scientific boundaries, EPA reference standards, API contracts, Flutter UI components, and test validations have been rigorously completed.
