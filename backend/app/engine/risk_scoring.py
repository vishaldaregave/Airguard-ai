"""
AirGuard AI - Explainable Environmental Exposure Risk Engine
Calculates deterministic exposure risk scores (0-100) with clear transparent factor breakdowns.
Does NOT provide medical diagnosis or make guarantees of health immunity.
"""
from typing import List, Optional

from app.schemas.pollutant import EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult, AQICategory
from app.schemas.risk import (
    ActivityRecommendation,
    EnvironmentalRiskScore,
    ExposureRiskLevel,
    RiskFactorContribution,
)


def calculate_exposure_risk(
    aqi_result: AQICalculationResult,
    obs: EnvironmentalObservationInput,
) -> EnvironmentalRiskScore:
    """
    Computes an explainable environmental exposure risk score based on:
    1. Base AQI severity (0-70 points)
    2. Multi-pollutant synergistic compounding (0-20 points)
    3. Meteorological stagnation & entrapment factor (0-10 points)
    """
    breakdown: List[RiskFactorContribution] = []
    total_score: float = 0.0

    # 1. Base Score from AQI
    if aqi_result.overall_aqi is not None:
        aqi_val = aqi_result.overall_aqi
        if aqi_val <= 50:
            base_points = (aqi_val / 50.0) * 15.0
        elif aqi_val <= 100:
            base_points = 15.0 + ((aqi_val - 50) / 50.0) * 15.0
        elif aqi_val <= 200:
            base_points = 30.0 + ((aqi_val - 100) / 100.0) * 20.0
        elif aqi_val <= 300:
            base_points = 50.0 + ((aqi_val - 200) / 100.0) * 15.0
        elif aqi_val <= 400:
            base_points = 65.0 + ((aqi_val - 300) / 100.0) * 10.0
        else:
            base_points = 75.0 + ((aqi_val - 400) / 100.0) * 5.0

        total_score += base_points
        breakdown.append(
            RiskFactorContribution(
                factor_name=f"Primary AQI Severity ({aqi_result.prominent_pollutant or 'Overall'})",
                contribution_score=round(base_points, 1),
                explanation=f"CPCB AQI level of {aqi_val} ({aqi_result.category.value if aqi_result.category else 'Unknown'}) contributes base ambient exposure stress.",
            )
        )
        primary_driver = aqi_result.prominent_pollutant or "Ambient Particulates"
    else:
        # Fallback when overall AQI could not be officially certified
        base_points = 20.0
        total_score += base_points
        breakdown.append(
            RiskFactorContribution(
                factor_name="Uncertified Baseline Assessment",
                contribution_score=base_points,
                explanation="Incomplete pollutant suite prevents official AQI; baseline conservative risk applied.",
            )
        )
        primary_driver = "Unspecified (Data Sparse)"

    # 2. Multi-Pollutant Synergistic Compounding
    elevated_pollutants = []
    compounding_points = 0.0

    for p_name, sub_res in aqi_result.sub_indices.items():
        if p_name != aqi_result.prominent_pollutant and sub_res.sub_index > 100:
            elevated_pollutants.append((p_name, sub_res.sub_index))

    if elevated_pollutants:
        for p_name, s_idx in elevated_pollutants:
            # Add up to 5 points per secondary elevated pollutant
            pts = min(6.0, (s_idx - 100) / 40.0 * 3.0 + 2.0)
            compounding_points += pts

        compounding_points = min(20.0, compounding_points)
        total_score += compounding_points

        pollutant_list_str = ", ".join([f"{p} (AQI {idx})" for p, idx in elevated_pollutants])
        breakdown.append(
            RiskFactorContribution(
                factor_name="Multi-Pollutant Synergistic Compounding",
                contribution_score=round(compounding_points, 1),
                explanation=(
                    f"Simultaneous elevation in {pollutant_list_str} creates compounding "
                    "irritant and systemic biological exposure beyond isolated particulate matter."
                ),
            )
        )

    # 3. Meteorological Stagnation / Trapping Factor
    met_points = 0.0
    met_reasons = []

    if obs.wind_speed_kmh is not None and obs.wind_speed_kmh < 6.0:
        met_points += 4.0
        met_reasons.append("calm wind speed (<6 km/h) impeding atmospheric dispersion")

    if obs.relative_humidity_pct is not None and obs.relative_humidity_pct > 75.0:
        met_points += 4.0
        met_reasons.append("high relative humidity (>75%) promoting secondary particulate entrapment")

    if met_points > 0:
        total_score += met_points
        breakdown.append(
            RiskFactorContribution(
                factor_name="Atmospheric Stagnation & Trapping",
                contribution_score=round(met_points, 1),
                explanation=f"Meteorological conditions ({', '.join(met_reasons)}) favor ground-level pollutant accumulation.",
            )
        )

    # Final bounded score (0 - 100)
    final_score = int(min(100, max(0, round(total_score))))

    # Determine Risk Level
    if final_score <= 20:
        risk_lvl = ExposureRiskLevel.LOW
        summary = "Minimal environmental exposure hazard. Outdoor conditions are generally clean."
    elif final_score <= 40:
        risk_lvl = ExposureRiskLevel.MODERATE
        summary = "Moderate atmospheric exposure. Sensitive individuals may experience mild airway irritation."
    elif final_score <= 60:
        risk_lvl = ExposureRiskLevel.ELEVATED
        summary = "Elevated exposure risk. Increased ambient particulate load requiring activity moderation."
    elif final_score <= 75:
        risk_lvl = ExposureRiskLevel.HIGH
        summary = "High environmental exposure risk. Outdoor physical exertion should be significantly reduced."
    elif final_score <= 90:
        risk_lvl = ExposureRiskLevel.VERY_HIGH
        summary = "Very high toxic pollutant burden. Limit outdoor presence; indoor filtration strongly recommended."
    else:
        risk_lvl = ExposureRiskLevel.HAZARDOUS
        summary = "Hazardous environmental conditions. Avoid outdoor exposure; hazardous atmospheric contamination."

    # Grounded Activity Recommendations
    activities = _generate_activity_recommendations(final_score, aqi_result.category)

    return EnvironmentalRiskScore(
        risk_score=final_score,
        risk_level=risk_lvl,
        risk_summary=summary,
        primary_driver=primary_driver,
        breakdown=breakdown,
        activity_recommendations=activities,
    )


def _generate_activity_recommendations(
    score: int, category: Optional[AQICategory]
) -> List[ActivityRecommendation]:
    """Generates structured, grounded activity guidance."""
    if score <= 25:
        return [
            ActivityRecommendation(
                activity_type="Outdoor Running / Cardio",
                feasibility="SAFE",
                guidance="Unrestricted outdoor exercise. Atmosphere is clean and suitable for high-ventilation workouts.",
            ),
            ActivityRecommendation(
                activity_type="Daily Commute & Travel",
                feasibility="SAFE",
                guidance="Standard transit without special protective gear.",
            ),
            ActivityRecommendation(
                activity_type="Children & Sensitive Groups",
                feasibility="SAFE",
                guidance="Full outdoor play and recreation permitted.",
            ),
            ActivityRecommendation(
                activity_type="Home Ventilation",
                feasibility="SAFE",
                guidance="Open windows for fresh air exchange.",
            ),
        ]
    elif score <= 45:
        return [
            ActivityRecommendation(
                activity_type="Outdoor Running / Cardio",
                feasibility="PROCEED_WITH_CAUTION",
                guidance="Safe for most people; individuals with respiratory sensitivities should monitor tolerance.",
            ),
            ActivityRecommendation(
                activity_type="Daily Commute & Travel",
                feasibility="SAFE",
                guidance="Normal commuting routines acceptable.",
            ),
            ActivityRecommendation(
                activity_type="Children & Sensitive Groups",
                feasibility="PROCEED_WITH_CAUTION",
                guidance="Outdoor play acceptable; take routine hydration and rest breaks.",
            ),
            ActivityRecommendation(
                activity_type="Home Ventilation",
                feasibility="SAFE",
                guidance="Ventilation recommended during mid-afternoon hours when surface dispersion is higher.",
            ),
        ]
    elif score <= 65:
        return [
            ActivityRecommendation(
                activity_type="Outdoor Running / Cardio",
                feasibility="REDUCE_DURATION",
                guidance="Avoid vigorous sprint or endurance sessions outdoors; substitute with indoor training.",
            ),
            ActivityRecommendation(
                activity_type="Daily Commute & Travel",
                feasibility="PROCEED_WITH_CAUTION",
                guidance="Keep car windows rolled up with AC set to internal recirculation mode.",
            ),
            ActivityRecommendation(
                activity_type="Children & Sensitive Groups",
                feasibility="REDUCE_DURATION",
                guidance="Limit prolonged outdoor physical games to under 30 minutes.",
            ),
            ActivityRecommendation(
                activity_type="Home Ventilation",
                feasibility="REDUCE_DURATION",
                guidance="Limit open-window periods; operate particulate air filtration indoors.",
            ),
        ]
    elif score <= 85:
        return [
            ActivityRecommendation(
                activity_type="Outdoor Running / Cardio",
                feasibility="AVOID",
                guidance="Do not run or do high-exertion workouts outdoors. Elevated pulmonary exposure hazard.",
            ),
            ActivityRecommendation(
                activity_type="Daily Commute & Travel",
                feasibility="PROCEED_WITH_CAUTION",
                guidance="Wear a certified N95 particulate respirator when walking along roadways or transit stops.",
            ),
            ActivityRecommendation(
                activity_type="Children & Sensitive Groups",
                feasibility="AVOID",
                guidance="Keep children, older adults, and asthma patients indoors in filtered spaces.",
            ),
            ActivityRecommendation(
                activity_type="Home Ventilation",
                feasibility="AVOID",
                guidance="Keep windows and exterior doors tightly closed. Run HEPA air purifiers.",
            ),
        ]
    else:  # Severe / Hazardous
        return [
            ActivityRecommendation(
                activity_type="Outdoor Running / Cardio",
                feasibility="AVOID",
                guidance="Completely prohibited. Severe pollution causes acute respiratory and vascular strain.",
            ),
            ActivityRecommendation(
                activity_type="Daily Commute & Travel",
                feasibility="AVOID",
                guidance="Avoid non-essential travel. Wear tight-fitting N95/FFP2 respirator for any outdoor exposure.",
            ),
            ActivityRecommendation(
                activity_type="Children & Sensitive Groups",
                feasibility="AVOID",
                guidance="Strict indoor isolation in clean-air zones. Monitor asthma management protocols.",
            ),
            ActivityRecommendation(
                activity_type="Home Ventilation",
                feasibility="AVOID",
                guidance="Maintain sealed indoor air space. Run continuous HEPA purifiers with active carbon stages.",
            ),
        ]
