# CPCB IND-AQI METHODOLOGY & DETERMINISTIC CALCULATION ENGINE

## 1. Mathematical Formulation
AirGuard AI implements the Central Pollution Control Board (CPCB) of India National Air Quality Index (IND-AQI) methodology in accordance with the official October 2014 CPCB technical report.

The sub-index $I_p$ for a given pollutant concentration $C_p$ is calculated via piecewise continuous linear interpolation across the corresponding health-risk breakpoint range:

$$I_p = \frac{I_{Hi} - I_{Lo}}{B_{Hi} - B_{Lo}} \times (C_p - B_{Lo}) + I_{Lo}$$

Where:
- $C_p$: Observed concentration of the pollutant (in $\mu g/m^3$, except CO in $mg/m^3$)
- $B_{Hi}$: Upper breakpoint concentration of the interval
- $B_{Lo}$: Lower breakpoint concentration of the interval
- $I_{Hi}$: Upper index value of the corresponding AQI category
- $I_{Lo}$: Lower index value of the corresponding AQI category

The calculated sub-index is rounded to the nearest integer using standard half-up rounding ($x.5 \to x + 1$) and bounded between $[0, 500]$.

---

## 2. Breakpoint Matrix & Averaging Periods

All concentrations are in $\mu g/m^3$, except CO which is measured in $mg/m^3$.

| AQI Category | AQI Range | PM10 (24h) | PM2.5 (24h) | NO2 (24h) | O3 (8h) | CO (8h, mg/m³) | SO2 (24h) | NH3 (24h) | Pb (24h) |
|---|---|---|---|---|---|---|---|---|---|
| **Good** | 0 – 50 | 0 – 50 | 0 – 30 | 0 – 40 | 0 – 50 | 0 – 1.0 | 0 – 40 | 0 – 200 | 0 – 0.5 |
| **Satisfactory** | 50 – 100 | 50 – 100 | 30 – 60 | 40 – 80 | 50 – 100 | 1.0 – 2.0 | 40 – 80 | 200 – 400 | 0.5 – 1.0 |
| **Moderate** | 100 – 200 | 100 – 250 | 60 – 90 | 80 – 180 | 100 – 168 | 2.0 – 10.0 | 80 – 380 | 400 – 800 | 1.0 – 2.0 |
| **Poor** | 200 – 300 | 250 – 350 | 90 – 120 | 180 – 280 | 168 – 208 | 10.0 – 17.0 | 380 – 800 | 800 – 1200 | 2.0 – 3.0 |
| **Very Poor** | 300 – 400 | 350 – 430 | 120 – 250 | 280 – 400 | 208 – 748 | 17.0 – 34.0 | 800 – 1600 | 1200 – 1800 | 3.0 – 3.5 |
| **Severe** | 400 – 500 | 430 – 500 | 250 – 350 | 400 – 500 | 748 – 1000 | 34.0 – 50.0 | 1600 – 2000 | 1800 – 2400 | 3.5 – 5.0 |

*Note on Continuity*: The official CPCB technical documentation publishes integer boundary tables for human readability (e.g. 0-30 then 31-60), but the underlying piecewise interpolation is continuous across category boundaries ($B_{Lo} = 30$, $B_{Hi} = 60$, $I_{Lo} = 50$, $I_{Hi} = 100$). Continuous boundaries prevent gaps or step-function artifacts for fractional concentration values (e.g., $30.5\ \mu g/m^3$).

---

## 3. Official CPCB Reference Validation Examples

### Example A: Satisfactory Level (PM2.5)
- Concentration $C_p = 45.0\ \mu g/m^3$
- Breakpoint Interval: $[30, 60]$, Index Range: $[50, 100]$
- Calculation:
  $$I_{PM2.5} = \frac{100 - 50}{60 - 30} \times (45 - 30) + 50 = \frac{50}{30} \times 15 + 50 = 25 + 50 = 75$$
- Sub-Index: **75** (Satisfactory)

### Example B: Very Poor Level (PM2.5)
- Concentration $C_p = 150.0\ \mu g/m^3$
- Breakpoint Interval: $[120, 250]$, Index Range: $[300, 400]$
- Calculation:
  $$I_{PM2.5} = \frac{400 - 300}{250 - 120} \times (150 - 120) + 300 = \frac{100}{130} \times 30 + 300 = 23.08 + 300 = 323.08 \to 323$$
- Sub-Index: **323** (Very Poor)

### Example C: Multi-Pollutant Overall AQI
- Pollutant Readings: $PM_{2.5} = 45\ \mu g/m^3$ ($I_p = 75$), $SO_2 = 50\ \mu g/m^3$ ($I_p = 63$), $NO_2 = 30\ \mu g/m^3$ ($I_p = 38$)
- Overall AQI: $\max(75, 63, 38) = 75$ (Satisfactory)
- Prominent Pollutant: **PM2.5**

---

## 4. CPCB Minimum Data Criteria Enforcement

According to CPCB mandate:
1. An overall AQI can only be calculated if **at least 3 pollutants** are monitored.
2. At least one of the monitored pollutants **MUST be either PM2.5 or PM10**.
3. Overall AQI is defined as the maximum of the valid pollutant sub-indices:
   $$\text{AQI} = \max(I_{p1}, I_{p2}, \dots, I_{pn})$$
4. The pollutant yielding the maximum sub-index is designated as the **Prominent (Dominant) Pollutant**. When tied, particulate matter ($PM_{2.5} / PM_{10}$) takes precedence due to chronic pulmonary and vascular persistence.

### Prohibition Against Standards Mixing:
The application calculates and reports **only Indian CPCB National AQI (IND-AQI)**. It never combines or substitutes US EPA AQI breakpoints, European Air Quality Index (CAQI) breakpoints, or WHO guidelines into the CPCB index pipeline.
