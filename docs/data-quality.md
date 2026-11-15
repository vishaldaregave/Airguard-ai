# AIRGUARD AI — DATA QUALITY & VALIDATION ENGINE

Data integrity is the bedrock of AirGuard AI. The Data Quality Engine enforces strict mathematical and scientific validation before any observation is passed to the CPCB AQI engine or presentation layer.

---

## 1. Principles of Data Integrity

1. **Zero Fabrication**: Measurements are never invented or simulated under a `LIVE` label.
2. **Missing is Not Zero**: A pollutant that is not monitored or fails quality checks is retained as `null` / `None`. It is **never** replaced with zero, as zero concentration would falsely depress AQI and exposure risk scores.
3. **Plausible Physical Bounds**: Sensor readings beyond physically plausible atmospheric limits are rejected as hardware malfunctions or calibration drifts.
4. **Transparent Data Provenance**: Every observation is stamped with its exact data source category: `LIVE`, `ESTIMATED`, `FORECAST`, `HISTORICAL`, or `DEMO_FIXTURE`.

---

## 2. Plausible Physical Upper Bounds

Atmospheric measurements exceeding these thresholds are flagged as invalid:

| Pollutant | CPCB Unit | Plausible Upper Bound | Notes |
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

## 3. Unit Normalization (Standard Temperature & Pressure - STP)

External providers report concentrations in differing units (e.g. $ppm$, $ppb$, $\mu g/m^3$, $mg/m^3$). All gaseous concentrations are converted to target CPCB units at STP ($25^\circ\text{C}$, $101.325\text{ kPa}$):

$$C_{\mu g/m^3} = C_{ppb} \times \frac{M}{24.45}$$

Where $M$ is the molecular weight:
- **$NO_2$** ($M = 46.01\text{ g/mol}$): $1\text{ ppb} = 1.88\ \mu g/m^3$
- **$SO_2$** ($M = 64.07\text{ g/mol}$): $1\text{ ppb} = 2.62\ \mu g/m^3$
- **$O_3$** ($M = 48.00\text{ g/mol}$): $1\text{ ppb} = 1.96\ \mu g/m^3$
- **$CO$** ($M = 28.01\text{ g/mol}$, target is $mg/m^3$): $1\text{ ppm} = 1.145\ mg/m^3$, and $1,000\ \mu g/m^3 = 1.0\ mg/m^3$
- **$NH_3$** ($M = 17.03\text{ g/mol}$): $1\text{ ppb} = 0.70\ \mu g/m^3$

---

## 4. CPCB Minimum Pollutant Criteria Enforcement

In accordance with Central Pollution Control Board (CPCB) methodology:
1. Overall AQI requires **at least 3 monitored pollutants**.
2. At least one of the monitored pollutants **must be Particulate Matter ($PM_{2.5}$ or $PM_{10}$)**.

### Incomplete Coverage Behavior:
- When an observation has fewer than 3 pollutants or lacks particulate matter:
  - The status is set to `INSUFFICIENT_POLLUTANTS`.
  - The overall AQI is kept as `null`.
  - Individual pollutant sub-indices are calculated and displayed transparently.
  - A clear explanation is returned to the user stating which criteria were not met.

---

## 5. Staleness & Freshness Verification

- Each observation records its raw source `timestamp`.
- The Data Quality Engine compares the observation timestamp with current UTC time:
  - If $\Delta t > 120\text{ minutes}$, the observation is flagged `is_stale = true`.
  - The dashboard surfaces a visual `STALE DATA` warning alongside the observation age in minutes.
