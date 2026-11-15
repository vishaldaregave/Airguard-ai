# CPCB IND-AQI METHODOLOGY & DETERMINISTIC CALCULATION ENGINE

## 1. Mathematical Formulation
AirGuard AI implements the Central Pollution Control Board (CPCB) of India National Air Quality Index (IND-AQI) methodology.

The sub-index $I_p$ for a given pollutant concentration $C_p$ is calculated via linear interpolation across the corresponding breakpoint range:

$$I_p = \frac{I_{Hi} - I_{Lo}}{B_{Hi} - B_{Lo}} \times (C_p - B_{Lo}) + I_{Lo}$$

Where:
- $C_p$: Observed concentration of the pollutant
- $B_{Hi}$: Upper breakpoint concentration of the interval
- $B_{Lo}$: Lower breakpoint concentration of the interval
- $I_{Hi}$: Upper index value of the corresponding AQI category
- $I_{Lo}$: Lower index value of the corresponding AQI category

The calculated sub-index is rounded to the nearest integer and bounded between $[0, 500]$.

## 2. Breakpoint Matrix
All units are in $\mu g/m^3$, except CO which is measured in $mg/m^3$.

| AQI Category | AQI Range | PM10 (24h) | PM2.5 (24h) | NO2 (24h) | O3 (8h) | CO (8h, mg/m³) | SO2 (24h) | NH3 (24h) | Pb (24h) |
|---|---|---|---|---|---|---|---|---|---|
| **Good** | 0 – 50 | 0 – 50 | 0 – 30 | 0 – 40 | 0 – 50 | 0 – 1.0 | 0 – 40 | 0 – 200 | 0 – 0.5 |
| **Satisfactory** | 51 – 100 | 51 – 100 | 31 – 60 | 41 – 80 | 51 – 100 | 1.1 – 2.0 | 41 – 80 | 201 – 400 | 0.5 – 1.0 |
| **Moderate** | 101 – 200 | 101 – 250 | 61 – 90 | 81 – 180 | 101 – 168 | 2.1 – 10.0 | 81 – 380 | 401 – 800 | 1.1 – 2.0 |
| **Poor** | 201 – 300 | 251 – 350 | 91 – 120 | 181 – 280 | 169 – 208 | 10.1 – 17.0 | 381 – 800 | 801 – 1200 | 2.1 – 3.0 |
| **Very Poor** | 301 – 400 | 351 – 430 | 121 – 250 | 281 – 400 | 209 – 748 | 17.1 – 34.0 | 801 – 1600 | 1201 – 1800 | 3.1 – 3.5 |
| **Severe** | 401 – 500 | 430+ | 250+ | 400+ | 748+ | 34.0+ | 1600+ | 1800+ | 3.5+ |

## 3. CPCB Minimum Data Criteria
According to CPCB mandate:
1. An overall AQI can only be calculated if **at least 3 pollutants** are monitored.
2. At least one of the monitored pollutants **MUST be either PM2.5 or PM10**.
3. Overall AQI is defined as the maximum of the valid pollutant sub-indices:
   $$\text{AQI} = \max(I_{p1}, I_{p2}, \dots, I_{pn})$$
4. The pollutant yielding the maximum sub-index is designated as the **Prominent (Dominant) Pollutant**.

If these minimum criteria are not met, the engine marks the result as `INSUFFICIENT_POLLUTANTS`, withholding a certified overall AQI while transparently displaying the individual sub-indices.

## 4. Explainable Exposure Risk Scoring (0–100)
Exposure risk scoring combines:
- **Base AQI Severity** (0–70 pts): Derived monotonically from certified AQI.
- **Multi-Pollutant Synergistic Compounding** (0–20 pts): Accounts for combined toxicological impact when secondary irritants (e.g. NO2, O3) are simultaneously elevated with particulates.
- **Meteorological Stagnation Factor** (0–10 pts): Accounts for low wind speed ($<6 \text{ km/h}$) and high relative humidity ($>75\%$) trapping surface pollutants.

Mandatory disclaimer is attached to all outputs prohibiting medical diagnosis.
