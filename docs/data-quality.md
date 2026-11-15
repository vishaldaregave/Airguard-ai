# AIRGUARD AI — DATA QUALITY & SCIENTIFIC VALIDATION ENGINE

Data integrity is the non-negotiable bedrock of AirGuard AI. The Data Quality Engine enforces strict thermodynamic, atmospheric, and mathematical validation before any observation is passed to the CPCB AQI engine or presentation layer.

---

## 1. Principles of Data Integrity

1. **Zero Fabrication**: Measurements are never invented or simulated under a `LIVE` label.
2. **Missing is Not Zero**: A pollutant that is not monitored or fails quality checks is retained as `null` / `None`. It is **never** replaced with zero, as zero concentration would falsely depress AQI and exposure risk scores.
3. **Plausible Physical Bounds**: Sensor readings beyond physically plausible atmospheric limits are rejected as hardware malfunctions or calibration drifts.
4. **Transparent Data Provenance**: Every observation is stamped with its exact data source category: `LIVE`, `ESTIMATED`, `FORECAST`, `HISTORICAL`, or `DEMO_FIXTURE`.
5. **Provider-Specific Cadence**: Freshness thresholds reflect provider update frequencies rather than an arbitrary universal threshold.
6. **Explicit Insufficient-Data States**: When monitoring coverage does not meet CPCB standards, an explicit `INSUFFICIENT_POLLUTANTS` status is returned with `overall_aqi = null`.

---

## 2. Plausible Physical Upper Bounds

Atmospheric ground-level measurements exceeding these thresholds are flagged as invalid and excluded from calculation:

| Pollutant | CPCB Unit | Plausible Upper Bound | Environmental Context |
|---|---|---|---|
| **PM2.5** | $\mu g/m^3$ | $2,000.0$ | Typical extreme episodic maximum ~1,000 |
| **PM10** | $\mu g/m^3$ | $3,000.0$ | Severe dust storms rarely exceed 2,500 |
| **NO2** | $\mu g/m^3$ | $1,000.0$ | Roadside peak ~500 |
| **SO2** | $\mu g/m^3$ | $2,500.0$ | Industrial plume peak |
| **CO** | $mg/m^3$ | $100.0$ | Urban traffic peak ~20–30 |
| **O3** | $\mu g/m^3$ | $1,200.0$ | Photochemical smog peak ~400–600 |
| **NH3** | $\mu g/m^3$ | $3,000.0$ | Agricultural/waste peak |
| **Pb** | $\mu g/m^3$ | $10.0$ | Industrial particulate lead limit |

---

## 3. Gas Unit Conversion & Reference Conditions

### A. Thermodynamic Reference Conditions (CPCB NAAQS / USEPA Standard)

External providers report concentrations in differing units ($ppm$, $ppb$, $\mu g/m^3$, $mg/m^3$). 

#### Scientific Clarification on "STP" vs Standard Reference State:
- **Conventional Chemical STP**: $0^\circ\text{C}$ ($273.15\text{ K}$) and $1\text{ atm}$ ($101.325\text{ kPa}$), yielding an ideal gas molar volume of $V_{m,stp} = 22.414\text{ L/mol}$.
- **CPCB / USEPA Standard Reference Conditions (SATP)**: $25.0^\circ\text{C}$ ($298.15\text{ K}$) and $1\text{ atm}$ ($101.325\text{ kPa}$ or $760\text{ mm Hg}$), yielding an ideal gas molar volume:

$$V_{m,ref} = \frac{R \cdot T_{ref}}{P_{ref}} = \frac{8.314462618 \times 298.15 \times 10}{1013.25} = 24.4654\text{ L/mol} = 0.0244654\text{ m}^3\text{/mol}$$

All CPCB National Ambient Air Quality Standards (NAAQS) and AQI breakpoint tables are calibrated to **$25.0^\circ\text{C}$ and $101.325\text{ kPa}$**. Applying $0^\circ\text{C}$ STP would introduce an artificial ~9.15% error in mass concentrations.

### B. Standard Reference Conversion Factors ($25^\circ\text{C}, 1\text{ atm}$)

Derived from $\frac{M}{V_{m,ref}}$:
- **$\text{NO}_2$** ($M = 46.0055\text{ g/mol}$): $1\text{ ppb} = \frac{46.0055}{24.4654} = 1.8804\ \mu g/m^3$ (rounded factor: $1.88$)
- **$\text{SO}_2$** ($M = 64.0660\text{ g/mol}$): $1\text{ ppb} = \frac{64.0660}{24.4654} = 2.6186\ \mu g/m^3$ (rounded factor: $2.62$)
- **$\text{O}_3$** ($M = 47.9982\text{ g/mol}$): $1\text{ ppb} = \frac{47.9982}{24.4654} = 1.9619\ \mu g/m^3$ (rounded factor: $1.96$)
- **$\text{CO}$** ($M = 28.0101\text{ g/mol}$, target unit is $mg/m^3$): 
  - $1\text{ ppm} = \frac{28.0101}{24.4654} = 1.1449\ mg/m^3$ (rounded factor: $1.145$)
  - $1\text{ ppb} = 0.001145\ mg/m^3$
  - $1,000\ \mu g/m^3 = 1.0\ mg/m^3$
- **$\text{NH}_3$** ($M = 17.0305\text{ g/mol}$): $1\text{ ppb} = \frac{17.0305}{24.4654} = 0.6961\ \mu g/m^3$ (rounded factor: $0.70$)

### C. Temperature and Pressure Aware Dynamic Conversion

When source feeds provide ambient temperature ($T$ in $^\circ\text{C}$) and surface pressure ($P$ in $hPa$):

$$V_m(T, P) = \frac{R \cdot (T + 273.15) \cdot 10}{P}\quad (\text{in L/mol})$$

$$C_{\mu g/m^3} = C_{ppb} \times \frac{M}{V_m(T, P)}$$

For CO in $mg/m^3$:
$$C_{mg/m^3} = C_{ppm} \times \frac{M}{V_m(T, P)}$$

When ambient $T$ or $P$ are unavailable, the engine falls back deterministically to CPCB Standard Reference Conditions ($25.0^\circ\text{C}, 1013.25\text{ hPa}$) and documents this in observation conversion metadata.

---

## 4. Provider-Specific Freshness & Staleness

A single universal staleness threshold does not reflect operational realities across heterogeneous sources. AirGuard AI enforces provider-calibrated thresholds:

| Provider | Data Type | Refresh Cadence | Staleness Threshold | Rationale |
|---|---|---|---|---|
| **CPCB / data.gov.in** | Ground CAAQMS | 60–120 min | **180 minutes** | Government validation lag and transmission windows |
| **OpenAQ v3** | Ground Station | Station-dependent (15–60 min) | **120 minutes** | International station ingestion cadence |
| **Open-Meteo** | Gridded Atmospheric Model | 60 min model cycle | **90 minutes** | Model cycles produce fresh hourly grids |
| **Demo Fixtures** | Offline Fixture | Synthetic | **120 minutes** | Local deterministic evaluation |

### Future Timestamp Handling
- Observations tagged as `FORECAST` legitimately carry future timestamps.
- Observations tagged as `LIVE`, `HISTORICAL`, or `ESTIMATED` with timestamps $>5\text{ minutes}$ in the future are flagged as clock drift anomalies and marked `is_stale = true`.

---

## 5. Station Metadata & Coordinate Validation

Before any monitoring station is admitted to the index:
1. **Latitude/Longitude Range**: Validated within $[-90.0, 90.0]$ and $[-180.0, 180.0]$.
2. **Null Island Rejection**: Coordinates $(0.0, 0.0)$ are rejected as uncalibrated or uninitialized GPS fixes.
3. **Distance Calculation**: Accurate distance from user location is calculated using the Haversine great-circle formula.

---

## 6. Deduplication

Historical time series from external providers are deduplicated on observation timestamp to eliminate identical overlapping model run cycles or repeated HTTP responses.

---

## 7. Explainable Exposure Risk Score Engine

The Environmental Exposure Risk Score ($S \in [0, 100]$) is distinct from the official CPCB AQI. It estimates cumulative ambient stress by integrating three deterministic components:

### Mathematical Formula:

$$S = \min\left(100, \max\left(0, \text{round}(S_{base} + S_{compounding} + S_{meteorology})\right)\right)$$

### Component Breakdown:
1. **Base AQI Severity ($0 - 75\text{ points}$)**:
   - AQI $0 - 50$: $S_{base} = \frac{AQI}{50} \times 15$
   - AQI $51 - 100$: $S_{base} = 15 + \frac{AQI - 50}{50} \times 15$
   - AQI $101 - 200$: $S_{base} = 30 + \frac{AQI - 100}{100} \times 20$
   - AQI $201 - 300$: $S_{base} = 50 + \frac{AQI - 200}{100} \times 15$
   - AQI $301 - 400$: $S_{base} = 65 + \frac{AQI - 300}{100} \times 10$
   - AQI $> 400$: $S_{base} = 75 + \frac{\min(AQI, 500) - 400}{100} \times 5$
   - *Data Sparse Fallback*: When CPCB criteria are incomplete ($overall\_aqi = null$), a conservative baseline of $20.0$ points is assigned and flagged as "Uncertified Baseline Assessment".

2. **Multi-Pollutant Synergistic Compounding ($0 - 20\text{ points}$)**:
   - Evaluates non-dominant secondary pollutants exceeding Moderate levels ($I_p > 100$).
   - For each secondary elevated pollutant: adds $\min\left(6.0, \frac{I_p - 100}{40} \times 3.0 + 2.0\right)$ points, capped at $20.0$ total points.

3. **Meteorological Stagnation & Trapping ($0 - 10\text{ points}$)**:
   - Calm winds ($< 6\text{ km/h}$): $+4.0$ points (impeded atmospheric horizontal dispersion).
   - High humidity ($> 75\%$): $+4.0$ points (promotes hygroscopic aerosol entrapment).
   - Synergistic trapping (both conditions met): $+2.0$ points ($10.0$ points total).

### Non-Medical Disclaimer:
The Environmental Exposure Risk Score is an operational air-mass vulnerability index designed to guide outdoor activity planning. **It does NOT constitute a clinical diagnosis, medical evaluation, or personalized health prognosis.**
