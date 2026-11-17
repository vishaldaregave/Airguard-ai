# AIRGUARD AI — MILESTONE 5.2.1 SCIENTIFIC VALIDATION REPORT
## Exposure Simulator & Personal Environmental Exposure Intelligence Audit

**Repository:** `D:\Development\Airgaurd-ai`  
**Milestone:** 5.2.1 — Exposure Scientific Validation Audit  
**Starting Commit:** `ce4e741` (Milestone 5.2 Completion)  
**Date:** November 17, 2026  
**Status:** Validated, Remediated, 100% Tests Passing, Zero Regressions  

---

## 1. Executive Summary

Milestone 5.2.1 conducted an independent scientific, dimensional, temporal, and data integrity audit of the Milestone 5.2 Exposure Simulator and Personal Environmental Exposure Intelligence engine.

The audit verified all physiological assumptions, mathematical formulas, dimensional relationships, regulatory averaging-period compatibility, temporal forecast integrations, and provider-specific freshness constraints. Where discrepancies or incomplete disclosures were identified (e.g. Table citations in the US EPA Exposure Factors Handbook, missing forecast interval disclosures, provider-specific staleness thresholds, negative custom concentrations), precise, non-breaking scientific corrections were implemented and thoroughly validated with automated tests.

---

## 2. Audit Findings & Remediations

### 2.1. Audit Area 1: Activity Ventilation Rates & EPA Exposure Factors Handbook Derivations

#### Findings:
1. **Citation Discrepancy**: In `exposure_engine.py`, the references originally cited `Table 6-1` of the US EPA Exposure Factors Handbook (2011 Edition) for short-term activity ventilation rates. 
   - **Verification**: In Chapter 6 of the 2011 EPA Exposure Factors Handbook (*Inhalation Rates*), **Table 6-1** provides **Long-Term (Daily) Inhalation Rates** in $\text{m}^3/\text{day}$ (mean adult: $15.3\text{–}16.0\,\text{m}^3/\text{day}$).
   - Short-term activity-dependent inhalation rates are reported in **Table 6-2** (*Summary of Recommended Values for Short-Term Inhalation Rates by Activity Level for Adults*, in $\text{m}^3/\text{min}$).
   - Furthermore, the classic benchmark hourly values for adults across activity categories originate from the **1997 EPA Exposure Factors Handbook (Chapter 5, Table 5-23)**:
     - Rest: $0.4\,\text{m}^3/\text{h}$
     - Sedentary Activities: $0.5\,\text{m}^3/\text{h}$
     - Light Activities: $1.0\,\text{m}^3/\text{h}$
     - Moderate Activities: $1.6\,\text{m}^3/\text{h}$
     - Heavy Activities: $3.2\,\text{m}^3/\text{h}$
2. **Empirical Transportation Studies**: The commuter and cycling inhalation rates are directly substantiated by peer-reviewed transport microenvironment literature:
   - *Zuurbier et al. (2009)* measured bus and car passenger ventilation at $10.1 \pm 2.4\,\text{L/min}$ ($0.60\,\text{m}^3/\text{h}$).
   - *Int Panis et al. (2010)* measured commuter cyclists ($15\text{–}18\,\text{km/h}$) at $35.2\,\text{L/min}$ ($2.11\,\text{m}^3/\text{h}$), matching the 95th percentile moderate-intensity category ($2.04\text{–}2.40\,\text{m}^3/\text{h}$) in EPA 2011 Table 6-2.
   - *Adams (1993)* measured walking at $20.0\,\text{L/min}$ ($1.20\,\text{m}^3/\text{h}$) and vigorous running at $46.7\,\text{L/min}$ ($2.80\,\text{m}^3/\text{h}$, within the High Intensity mean of $2.82\text{–}3.18\,\text{m}^3/\text{h}$ in EPA 2011 Table 6-2).

#### Remediation Applied:
- Corrected all activity profile citations in [`backend/app/engine/exposure_engine.py`](file:///D:/Development/Airgaurd-ai/backend/app/engine/exposure_engine.py) to explicitly cite **Table 6-2 of the 2011 Edition**, **Table 5-23 of the 1997 Edition**, and empirical citations (*Adams 1993, Zuurbier 2009, Int Panis 2010*).
- Preserved all numerical inhalation rates ($0.50, 0.60, 1.20, 2.10, 2.80\,\text{m}^3/\text{h}$) as they are scientifically grounded and aligned with empirical measurement.

---

### 2.2. Audit Area 2: Dimensional Correctness & Unit Conversions

The calculation engine was audited for dimensional consistency across all physical quantities:

1. **Concentration-Time Exposure ($C \times t$)**:
   $$\text{Exposure Index}_p = C_p \times t$$
   - Particulates & Trace Gases: $[\mu\text{g/m}^3] \times [\text{h}] = [\mu\text{g}\cdot\text{h/m}^3]$. Dimensions: $[M \cdot T \cdot L^{-3}]$.
   - Carbon Monoxide ($\text{CO}$): $[\text{mg/m}^3] \times [\text{h}] = [\text{mg}\cdot\text{h/m}^3]$. Dimensions: $[M \cdot T \cdot L^{-3}]$.
   - Verified: Fully dimensionally consistent.

2. **Ventilation Volume ($V_E \times t$)**:
   $$V_{\text{inhaled}} = V_E \times t$$
   - $[\text{m}^3/\text{h}] \times [\text{h}] = [\text{m}^3]$. Dimensions: $[L^3 \cdot T^{-1}] \times [T] = [L^3]$.
   - Verified: Fully dimensionally consistent.

3. **Gross Inhaled Pollutant Mass ($C \times V_E \times t$)**:
   $$\text{Estimated Inhaled Mass}_p = C_p \times V_E \times t$$
   - Particulates & Trace Gases: $[\mu\text{g/m}^3] \times [\text{m}^3/\text{h}] \times [\text{h}] = [\mu\text{g}]$. Dimensions: $[M \cdot L^{-3}] \times [L^3] = [M]$.
   - Carbon Monoxide ($\text{CO}$): $[\text{mg/m}^3] \times [\text{m}^3] = [\text{mg}]$. Dimensions: $[M]$.
   - Verified: Fully dimensionally consistent.

4. **Gas Unit Conversions (ppb/ppm to $\mu\text{g/m}^3$ / $\text{mg/m}^3$)**:
   - Evaluated under CPCB NAAQS Standard Reference Conditions ($25.0^\circ\text{C}, 1013.25\,\text{hPa}$, molar volume $V_m = 24.4654\,\text{L/mol}$):
     - $\text{NO}_2$ ($M = 46.0055\,\text{g/mol}$): $1\,\text{ppb} \times \frac{46.0055}{24.4654} = 1.8804\,\mu\text{g/m}^3$.
     - $\text{SO}_2$ ($M = 64.066\,\text{g/mol}$): $1\,\text{ppb} \times \frac{64.066}{24.4654} = 2.6186\,\mu\text{g/m}^3$.
     - $\text{CO}$ ($M = 28.010\,\text{g/mol}$): $1\,\text{ppm} \times \frac{28.010}{24.4654} = 1.1449\,\text{mg/m}^3$.
     - $\text{O}_3$ ($M = 47.9982\,\text{g/mol}$): $1\,\text{ppb} \times \frac{47.9982}{24.4654} = 1.9619\,\mu\text{g/m}^3$.
   - Verified: All conversion factors strictly follow ideal gas law derivations.

5. **Scenario Comparison Deltas**:
   - $\Delta \text{Mass} = \text{Mass}_B - \text{Mass}_A$ (Dimension $[M]$).
   - $\%\Delta = \frac{\text{Mass}_B - \text{Mass}_A}{\text{Mass}_A} \times 100\%$ (Dimensionless).
   - Preserves zero division protection (returns $0.0\%$ when both are zero; preserves `None` if baseline is zero and alternative $> 0$).

---

### 2.3. Audit Area 3: Non-Clinical Boundaries & Output Disclaimers

#### Findings:
All API responses, labels, and AI explanations were audited for clinical terminology:
- Zero clinical diagnoses or personal disease risk predictions are made.
- Clear physical boundary: Gross inhaled air mass is explicitly differentiated from internal biological absorption, pulmonary retention fractions, or target organ dose.
- Standard disclaimer enforced across all endpoints:
  > *"Scientific Environmental Advisory: AirGuard AI provides deterministic physical exposure estimates based on ambient monitoring data and respiratory ventilation factors. Estimated inhaled mass represents gross air intake and does NOT represent absorbed internal dose or deposited pulmonary fraction. This simulation does not constitute clinical diagnostic advice, personal health forecasting, or a guarantee of safety."*

---

### 2.4. Audit Area 4: Temporal Integration & Forecast Window Modeling

#### Findings:
1. **Multi-Horizon Integration**: Forecast simulations evaluate exposure across an activity window $[t_{\text{start}}, t_{\text{end}}]$ by querying discrete forecast horizons ($+1\text{h}, +3\text{h}, +6\text{h}, +12\text{h}, +24\text{h}$).
2. **Prior Limitation**: When a pollutant's forecast horizon was missing, the engine fell back to the current observation without explicitly disclosing the fallback to the user.

#### Remediation Applied:
- Updated [`exposure_service.py`](file:///D:/Development/Airgaurd-ai/backend/app/services/exposure_service.py) to:
  1. Record the exact discrete horizon steps used to integrate the window:
     `Temporal Forecast Integration: Window (+Xh to +Yh) integrated across N discrete horizon step(s) ([1, 3]h).`
  2. Detect missing forecast intervals and disclose fallback proxy usage:
     `Missing Forecast Step Fallback: Prediction steps for [Pollutants] were unavailable; current ambient observation persisted as baseline proxy.`

---

### 2.5. Audit Area 5: Provider-Aware Freshness & Stale Data Rejection

#### Findings:
1. In Milestone 5.2, `curr_res.is_stale` was flagged, but the disclaimer hardcoded `"Warning: environmental observation is older than 120 minutes."`
2. However, AirGuard AI's established provider freshness thresholds ([`backend/app/services/quality.py`](file:///D:/Development/Airgaurd-ai/backend/app/services/quality.py)) differ by provider:
   - **CPCB**: $180\,\text{minutes}$
   - **Open-Meteo**: $90\,\text{minutes}$
   - **OpenAQ**: $120\,\text{minutes}$
   - **Demo Fixtures**: $120\,\text{minutes}$
3. Furthermore, when data was stale, the engine previously still calculated pollutant metrics while tagging `status="STALE_DATA"`, which conflicted with the requirement *"Do not calculate when the input data is stale or invalid"*.

#### Remediation Applied:
- Reused `PROVIDER_STALENESS_THRESHOLDS_MINUTES` and `check_observation_staleness` from `app.services.quality`.
- If observation is stale:
  1. Status set to `STALE_DATA`.
  2. **Calculations withheld**: `pollutants = {}` (empty), preventing misleading cumulative intake outputs.
  3. Dynamic provider threshold reported:
     `Stale Data Rejection: Telemetry from {obs.provider} is {age} minutes old, which exceeds the provider-specific freshness threshold of {provider_thresh} minutes. Exposure calculation is withheld to avoid inaccurate estimates.`

---

### 2.6. Audit Area 6: Averaging-Period Compatibility

#### Findings:
- Under CPCB NAAQS, physical stations publish 24-hour averages for $\text{PM}_{2.5}$, $\text{PM}_{10}$, $\text{NO}_2$, $\text{SO}_2$, $\text{NH}_3$, $\text{Pb}$, and 8-hour averages for $\text{CO}$ and $\text{O}_3$.
- Applying a 24-hr regulatory average to a 30-minute, 1-hour, or 2-hour workout assumes uniform temporal dispersion across the session window. Real-world short-term transient spikes (e.g. traffic exhaust, boundary layer transitions) can deviate substantially from the 24-hr mean.

#### Remediation Applied:
- Embedded explicit **Averaging-Period Compatibility Disclosures** into:
  1. `CALCULATION_METHODOLOGY_NOTE` in `exposure_engine.py`.
  2. Every simulated response for sub-daily activities ($< 24\text{h}$):
     `Averaging-Period Disclosure: {duration_minutes}-minute exposure evaluated against regulatory 24-hr (PM2.5, PM10, NO2, SO2) and 8-hr (CO, O3) monitoring averages assuming uniform temporal concentration across the activity window.`

---

### 2.7. Audit Area 7: DEMO_FIXTURE Provenance & Edge Case Boundaries

#### Remediations Applied:
1. **DEMO_FIXTURE Labeling**: When synthetic fixtures are used (`allow_demo=True`), the station name is guaranteed to be prefixed with `[DEMO FIXTURE]` and a visible `DEMO DATA NOTICE` is injected into `disclaimer`.
2. **Negative Concentrations Validation**: Added Pydantic `@field_validator("custom_concentrations")` to [`SimulateExposureRequest`](file:///D:/Development/Airgaurd-ai/backend/app/schemas/exposure.py) rejecting negative custom concentrations with HTTP 422.
3. **Duration Boundaries**: Rejection of durations $< 15$ min or $> 480$ min strictly maintained with HTTP 422.
4. **Missing Pollutant Handling**: Missing observations remain `None`/unavailable with `is_available: false` (never coerced to 0).

---

## 3. Automated Test Verification Results

### 3.1. Backend Pytest Execution
Command:
```powershell
.\venv\Scripts\pytest.exe tests/ -v
```
**Result: 129 PASSED out of 129 tests (100% pass rate in 11.11s)**

New dedicated validation tests in [`tests/test_exposure_simulator.py`](file:///D:/Development/Airgaurd-ai/backend/tests/test_exposure_simulator.py):
1. `test_concentration_time_exposure_calculation`: PASSED
2. `test_estimated_inhaled_mass_calculation`: PASSED
3. `test_missing_pollutant_preserved_as_none_never_zero`: PASSED
4. `test_invalid_negative_values_rejected`: PASSED
5. `test_activity_profiles_completeness_and_references`: PASSED
6. `test_api_get_activity_profiles`: PASSED
7. `test_api_simulate_custom_concentrations`: PASSED
8. `test_api_simulate_duration_boundary_validation`: PASSED
9. `test_api_compare_scenarios`: PASSED
10. `test_api_explain_exposure`: PASSED
11. `test_negative_custom_concentrations_rejected_with_422`: PASSED
12. `test_activity_profiles_epa_citations_audit`: PASSED
13. `test_dimensional_correctness_across_criteria_pollutants`: PASSED
14. `test_averaging_period_compatibility_disclosure`: PASSED
15. `test_demo_fixture_provenance_and_labeling`: PASSED
16. `test_stale_data_provider_aware_rejection`: PASSED

### 3.2. Frontend Flutter Verification
Commands:
```powershell
C:\flutter\bin\dart.bat analyze lib test
C:\flutter\bin\flutter.bat test
```
**Results:**
- `dart analyze lib test`: **No issues found!** (4.5s)
- `flutter test`: **32 / 32 tests passed!** (1.0s)

---

## 4. Scientific & Data Limitations

1. **Non-Biological Gross Intake**: The simulator models inspired environmental air volume ($V_{\text{air}} = V_E \times t$) and gross constituent pollutant mass ($C \times V_{\text{air}}$). It does not compute internal tissue deposition, alveolar absorption, chemical clearance rates, or biomarker concentrations (e.g. carboxyhemoglobin saturation from $\text{CO}$).
2. **Fixed Adult Mean Ventilation**: Inhalation rates ($0.50\text{–}2.80\,\text{m}^3/\text{h}$) represent healthy adult population central tendencies. Individual ventilation rates vary widely by age, sex, weight, aerobic fitness ($\text{VO}_2\text{ max}$), and chronic respiratory conditions (e.g. asthma, COPD).
3. **Temporal Dispersion Uniformity**: Exposure calculations over sub-hourly durations ($15\text{–}60\,\text{min}$) against hourly/daily monitoring station data assume constant ambient concentration throughout that window.
4. **Indoor vs Ambient Outdoor Air**: Ambient monitoring stations measure regional outdoor air quality. Indoor microenvironments (buildings with HEPA air filtration) typically experience substantially lower particulate concentrations than outdoor monitors indicate.
