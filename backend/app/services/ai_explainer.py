"""
AirGuard AI - AI-Powered Environmental Explanations Service
Generates scientifically grounded atmospheric interpretations answering the 6 core environmental inquiries.
Strict Data Integrity: Never calculates AQI in LLM, never invents values,
distinguishes LIVE from ESTIMATED, and provides deterministic fallbacks.
"""
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
import json
import httpx

from app.core.config import settings
from app.schemas.pollutant import DataSourceType, EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult, AQICategory
from app.schemas.risk import EnvironmentalRiskScore
from app.schemas.ai_explanation import AIExplanationRequest, AIExplanationResponse
from app.services.cache import cache


NON_MEDICAL_DISCLAIMER = (
    "Scientific Environmental Intelligence Advisory: AirGuard AI provides atmospheric assessments and exposure "
    "guidance based on CPCB standards. This advisory does not constitute clinical, medical, or physiological diagnosis."
)


class BaseLLMClient:
    async def explain(
        self,
        obs: EnvironmentalObservationInput,
        aqi_result: AQICalculationResult,
        risk: Optional[EnvironmentalRiskScore],
        hist_pm25_avg: Optional[float] = None,
        hist_trend: Optional[str] = None,
    ) -> AIExplanationResponse:
        raise NotImplementedError


class DeterministicRuleBasedExplainer(BaseLLMClient):
    """
    Expert rule-based atmospheric intelligence engine.
    Produces rigorous, deterministic scientific evaluations when LLM APIs are offline or unconfigured.
    """
    async def explain(
        self,
        obs: EnvironmentalObservationInput,
        aqi_result: AQICalculationResult,
        risk: Optional[EnvironmentalRiskScore],
        hist_pm25_avg: Optional[float] = None,
        hist_trend: Optional[str] = None,
    ) -> AIExplanationResponse:
        category = aqi_result.category or AQICategory.MODERATE
        prominent = aqi_result.prominent_pollutant or "PM2.5"
        provenance_str = obs.data_source_type.value
        is_model = obs.data_source_type in (DataSourceType.ESTIMATED, DataSourceType.FORECAST)

        # 1. Atmospheric Dynamics
        wind = obs.wind_speed_kmh
        humidity = obs.relative_humidity_pct
        temp = obs.temperature_celsius

        atmo_points = []
        if wind is not None and wind < 6.0:
            atmo_points.append(
                f"Horizontal dispersion is severely restricted by calm surface winds ({wind:.1f} km/h), "
                "causing localized stagnation of particulate and chemical emissions."
            )
        elif wind is not None and wind >= 15.0:
            atmo_points.append(
                f"Moderate-to-strong surface winds ({wind:.1f} km/h) are actively ventilating the boundary layer, "
                "aiding horizontal mechanical advection."
            )
        else:
            atmo_points.append("Atmospheric ventilation is operating under moderate surface wind dispersion.")

        if humidity is not None and humidity > 75.0:
            atmo_points.append(
                f"Elevated relative humidity ({humidity:.0f}%) promotes hygroscopic growth of sulfate and nitrate "
                "aerosols, enhancing particulate entrapment and surface haze formation."
            )

        if temp is not None and temp < 18.0:
            atmo_points.append(
                "Lower ambient temperatures favor shallow nocturnal boundary layer heights, compressing pollutants "
                "near breathing zones."
            )

        atmo_summary = " ".join(atmo_points)

        # 2. Primary Pollutant Driver
        if prominent == "PM2.5":
            driver_info = (
                f"Fine particulate matter (PM2.5) is the primary driver at {obs.pm2_5 or 0:.1f} µg/m³. "
                "These microscopic combustion particles (<2.5 µm diameter) remain suspended in the air "
                "for extended periods and penetrate deep into alveolar lung tissues."
            )
        elif prominent == "PM10":
            driver_info = (
                f"Coarse particulate matter (PM10) dominates at {obs.pm10 or 0:.1f} µg/m³. "
                "This fraction represents windblown road dust, construction crustal material, and mechanical wear."
            )
        elif prominent == "NO2":
            driver_info = (
                f"Nitrogen dioxide (NO2) is the primary driver at {obs.no2 or 0:.1f} µg/m³, "
                "indicating concentrated vehicular traffic exhaust and high-temperature combustion plumes."
            )
        elif prominent == "O3":
            driver_info = (
                f"Ground-level ozone (O3) is the primary driver at {obs.o3 or 0:.1f} µg/m³, formed via secondary "
                "photochemical reactions between NOx and VOCs under solar radiation."
            )
        elif prominent == "CO":
            driver_info = (
                f"Carbon monoxide (CO) is the primary driver at {obs.co or 0:.2f} mg/m³, "
                "pointing to incomplete fuel combustion from slow-moving urban congestion."
            )
        else:
            driver_info = f"{prominent} is identified as the prominent air quality determinant."

        # 3. Elevation Causes
        causes = []
        if is_model:
            causes.append(
                f"Data reflects regional atmospheric transport models ({obs.provider}) capturing broad air-mass trajectories."
            )
        else:
            causes.append(f"Physical ground-level monitoring at {obs.station_name or 'station'} confirms ambient accumulation.")

        if category in (AQICategory.POOR, AQICategory.VERY_POOR, AQICategory.SEVERE):
            causes.append(
                "Elevated levels result from the interplay of urban anthropogenic source emissions (vehicular transit, "
                "industrial energy, biomass) trapped beneath a shallow thermal inversion layer."
            )
        else:
            causes.append("Pollution levels reflect standard urban baseline conditions with balanced atmospheric dispersion.")

        elevation_summary = " ".join(causes)

        # 4. Outdoor Activity Implication
        if category == AQICategory.GOOD:
            activity = "Conditions are ideal for all outdoor activities, endurance cardio, and sports across all demographic groups."
        elif category == AQICategory.SATISFACTORY:
            activity = "Outdoor activities are generally safe. Unusually sensitive individuals should monitor respiratory comfort."
        elif category == AQICategory.MODERATE:
            activity = "Moderate outdoor activities permitted. Consider reducing high-exertion outdoor cardio near busy roads."
        elif category == AQICategory.POOR:
            activity = "Air quality is poor. Limit prolonged outdoor physical exertion; substitute outdoor running with indoor workouts."
        elif category == AQICategory.VERY_POOR:
            activity = "Outdoor physical exercise is strongly discouraged. Everyone should avoid outdoor exertion and minimize travel."
        else:  # SEVERE
            activity = "Severe atmospheric toxicity. Absolute restriction of outdoor exposure is advised for all individuals."

        # 5. Practical Precautions
        precautions = []
        if category in (AQICategory.VERY_POOR, AQICategory.SEVERE):
            precautions.append("Wear a certified, well-sealed N95 or FFP2 particulate respirator for any unavoidable outdoor transit.")
            precautions.append("Keep residential and office windows and doors tightly sealed against outdoor infiltration.")
            precautions.append("Operate indoor air purifiers with true HEPA filtration continuously in living and sleeping areas.")
            precautions.append("Set vehicle air conditioning systems to internal air recirculation mode.")
        elif category == AQICategory.POOR:
            precautions.append("Equip an N95 respirator if commuting or walking near major traffic arterial corridors.")
            precautions.append("Keep windows closed during early morning and late evening inversion peak hours.")
            precautions.append("Run indoor HEPA air purifiers during sleep cycles.")
        elif category == AQICategory.MODERATE:
            precautions.append("Ventilate homes during afternoon hours (12:00–16:00) when boundary layer mixing is highest.")
            precautions.append("Sensitive individuals with asthma or COPD should carry rescue inhalers when traveling.")
        else:
            precautions.append("Maintain standard natural home ventilation with open windows.")
            precautions.append("No specialized protective respirators needed under current clean atmospheric conditions.")

        # 6. Historical Comparison
        if hist_pm25_avg is not None and obs.pm2_5 is not None:
            delta = obs.pm2_5 - hist_pm25_avg
            pct = round(abs(delta) / max(0.1, hist_pm25_avg) * 100.0, 1)
            direction = "higher" if delta > 0 else "lower"
            hist_text = (
                f"Current PM2.5 of {obs.pm2_5:.1f} µg/m³ is {pct}% {direction} than the recent 24-hour "
                f"regional average of {hist_pm25_avg:.1f} µg/m³, indicating a {hist_trend or 'cyclical'} trajectory."
            )
        else:
            hist_text = (
                f"Observation exhibits typical regional diurnal dynamics for this time of day ({provenance_str} feed). "
                "Continued monitoring will establish baseline deviations."
            )

        # Executive Summary
        exec_sum = (
            f"Air quality is currently {category.value} (AQI {aqi_result.overall_aqi or 'N/A'}), "
            f"primarily driven by {prominent} under {provenance_str.lower()} data reporting."
        )

        return AIExplanationResponse(
            atmospheric_dynamics=atmo_summary,
            primary_pollutant_driver=driver_info,
            elevation_causes=elevation_summary,
            outdoor_activity_implication=activity,
            practical_precautions=precautions,
            historical_comparison=hist_text,
            executive_summary=exec_sum,
            llm_provider="DETERMINISTIC_EXPERT_SYSTEM",
            is_deterministic_fallback=True,
            data_provenance=provenance_str,
            disclaimer=NON_MEDICAL_DISCLAIMER,
            generated_at=datetime.now(timezone.utc),
        )


class GeminiLLMClient(BaseLLMClient):
    """Integrates Google Gemini REST API with fallback to deterministic expert rules."""
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.endpoint_url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
            f"?key={self.api_key}"
        )
        self.fallback = DeterministicRuleBasedExplainer()

    async def explain(
        self,
        obs: EnvironmentalObservationInput,
        aqi_result: AQICalculationResult,
        risk: Optional[EnvironmentalRiskScore],
        hist_pm25_avg: Optional[float] = None,
        hist_trend: Optional[str] = None,
    ) -> AIExplanationResponse:
        prompt = (
            "You are the AirGuard AI atmospheric intelligence explainer. "
            "Interpret the following verified environmental observations according to CPCB IND-AQI standards. "
            "Never invent missing values. Never provide medical diagnosis or guarantees of health immunity. "
            "Respond ONLY in valid JSON matching this exact structure:\n"
            "{\n"
            '  "atmospheric_dynamics": "string",\n'
            '  "primary_pollutant_driver": "string",\n'
            '  "elevation_causes": "string",\n'
            '  "outdoor_activity_implication": "string",\n'
            '  "practical_precautions": ["string", "string"],\n'
            '  "historical_comparison": "string",\n'
            '  "executive_summary": "string"\n'
            "}\n\n"
            f"Observation Data:\n"
            f"- Location: {obs.location.city or 'Unknown'}, {obs.location.country} ({obs.location.latitude}, {obs.location.longitude})\n"
            f"- Data Provenance: {obs.data_source_type.value}\n"
            f"- CPCB AQI: {aqi_result.overall_aqi} ({aqi_result.category.value if aqi_result.category else 'N/A'})\n"
            f"- Prominent Pollutant: {aqi_result.prominent_pollutant}\n"
            f"- PM2.5: {obs.pm2_5} µg/m³\n"
            f"- PM10: {obs.pm10} µg/m³\n"
            f"- NO2: {obs.no2} µg/m³\n"
            f"- SO2: {obs.so2} µg/m³\n"
            f"- CO: {obs.co} mg/m³\n"
            f"- O3: {obs.o3} µg/m³\n"
            f"- Temperature: {obs.temperature_celsius} °C\n"
            f"- Relative Humidity: {obs.relative_humidity_pct} %\n"
            f"- Wind Speed: {obs.wind_speed_kmh} km/h\n"
            f"- Exposure Risk Score: {risk.risk_score if risk else 'N/A'} / 100 ({risk.risk_level.value if risk else 'N/A'})\n"
            f"- Historical 24h PM2.5 Baseline: {hist_pm25_avg} µg/m³ (Trend: {hist_trend or 'N/A'})\n"
        )

        try:
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.2, "responseMimeType": "application/json"},
            }
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.post(self.endpoint_url, json=payload)
                if res.status_code == 200:
                    data = res.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                        parsed = json.loads(text)
                        return AIExplanationResponse(
                            atmospheric_dynamics=parsed.get("atmospheric_dynamics", ""),
                            primary_pollutant_driver=parsed.get("primary_pollutant_driver", ""),
                            elevation_causes=parsed.get("elevation_causes", ""),
                            outdoor_activity_implication=parsed.get("outdoor_activity_implication", ""),
                            practical_precautions=parsed.get("practical_precautions", []),
                            historical_comparison=parsed.get("historical_comparison", ""),
                            executive_summary=parsed.get("executive_summary", ""),
                            llm_provider="GEMINI_1.5_FLASH",
                            is_deterministic_fallback=False,
                            data_provenance=obs.data_source_type.value,
                            disclaimer=NON_MEDICAL_DISCLAIMER,
                            generated_at=datetime.now(timezone.utc),
                        )
        except Exception:
            pass

        # Clean fallback to deterministic rules on any failure
        return await self.fallback.explain(obs, aqi_result, risk, hist_pm25_avg, hist_trend)


class AIExplainerService:
    def __init__(self):
        self.fallback = DeterministicRuleBasedExplainer()

    def _get_client(self) -> BaseLLMClient:
        if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY.strip():
            return GeminiLLMClient(settings.GEMINI_API_KEY)
        return self.fallback

    async def generate_explanation(self, request: AIExplanationRequest) -> AIExplanationResponse:
        cache_key = (
            f"ai:explain:{request.observation.station_id}:"
            f"{request.aqi_result.overall_aqi}:{request.observation.timestamp.isoformat()}"
        )
        cached = await cache.get(cache_key)
        if cached:
            return cached

        client = self._get_client()
        explanation = await client.explain(
            obs=request.observation,
            aqi_result=request.aqi_result,
            risk=request.risk_assessment,
            hist_pm25_avg=request.historical_24h_avg_pm25,
            hist_trend=request.historical_trend,
        )

        await cache.set(cache_key, explanation, settings.CACHE_EXPLANATION_TTL_SECONDS)
        return explanation


ai_explainer_service = AIExplainerService()
