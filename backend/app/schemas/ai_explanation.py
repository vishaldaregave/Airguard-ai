"""
AirGuard AI - AI Explanation Data Contracts and Schemas
Strict grounding: structured insights answering the 6 core environmental inquiries
with non-medical disclaimers and deterministic fallbacks.
"""
from typing import Dict, List, Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.schemas.pollutant import EnvironmentalObservationInput
from app.schemas.aqi import AQICalculationResult
from app.schemas.risk import EnvironmentalRiskScore


class AIExplanationRequest(BaseModel):
    observation: EnvironmentalObservationInput = Field(..., description="Current verified environmental observation")
    aqi_result: AQICalculationResult = Field(..., description="Deterministic CPCB AQI calculation outcome")
    risk_assessment: Optional[EnvironmentalRiskScore] = Field(None, description="Explainable exposure risk assessment")
    historical_24h_avg_pm25: Optional[float] = Field(None, description="24-hour historical baseline for PM2.5")
    historical_trend: Optional[str] = Field(None, description="Recent trend: RISING, FALLING, or STABLE")


class AIExplanationResponse(BaseModel):
    # 6 Core Environmental Intelligence Dimensions
    atmospheric_dynamics: str = Field(
        ..., description="What is happening in the atmosphere (dispersion, boundary layer, entrapment)?"
    )
    primary_pollutant_driver: str = Field(
        ..., description="Which pollutant contributes most to the current condition and its physical characteristics?"
    )
    elevation_causes: str = Field(
        ..., description="Why might the pollution level be elevated (meteorology, terrain, anthropogenic context)?"
    )
    outdoor_activity_implication: str = Field(
        ..., description="What does this mean for ordinary outdoor activity and exercise?"
    )
    practical_precautions: List[str] = Field(
        ..., description="Practical non-medical precautions (ventilation, filtration, mask guidance)"
    )
    historical_comparison: str = Field(
        ..., description="How does today's condition compare with available historical observations?"
    )

    # Executive synthesis and metadata
    executive_summary: str = Field(..., description="One-sentence high-level atmospheric briefing")
    llm_provider: str = Field(..., description="LLM provider name or DETERMINISTIC_FALLBACK")
    is_deterministic_fallback: bool = Field(False, description="True if generated via deterministic expert rules")
    data_provenance: str = Field(..., description="Data provenance of underlying observation (LIVE, ESTIMATED, etc.)")
    disclaimer: str = Field(
        "Scientific Environmental Intelligence Advisory: AirGuard AI provides atmospheric assessments and exposure guidance based on CPCB standards. This advisory does not constitute clinical, medical, or physiological diagnosis.",
        description="Mandatory non-medical disclaimer"
    )
    generated_at: datetime = Field(..., description="UTC generation timestamp")
