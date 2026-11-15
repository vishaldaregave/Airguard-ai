"""
AirGuard AI - Environmental Exposure Risk Schemas
Explainable risk score grounded in verified environmental data.
Does NOT provide medical diagnosis or claim guaranteed health protection.
"""
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class ExposureRiskLevel(str, Enum):
    LOW = "LOW"
    MODERATE = "MODERATE"
    ELEVATED = "ELEVATED"
    HIGH = "HIGH"
    VERY_HIGH = "VERY_HIGH"
    HAZARDOUS = "HAZARDOUS"


class RiskFactorContribution(BaseModel):
    factor_name: str = Field(..., description="Name of the contributing environmental parameter")
    contribution_score: float = Field(..., description="Numerical impact points on exposure score")
    explanation: str = Field(..., description="Clear deterministic explanation of why this factor contributed")


class ActivityRecommendation(BaseModel):
    activity_type: str = Field(..., description="Activity category (e.g. Outdoor Running, Commute, Children Play, Ventilation)")
    feasibility: str = Field(..., description="SAFE, PROCEED_WITH_CAUTION, REDUCE_DURATION, AVOID")
    guidance: str = Field(..., description="Actionable guideline grounded in environmental measurements")


class EnvironmentalRiskScore(BaseModel):
    risk_score: int = Field(..., ge=0, le=100, description="Composite environmental exposure risk score (0-100)")
    risk_level: ExposureRiskLevel = Field(..., description="Risk category")
    risk_summary: str = Field(..., description="Concise, verified description of overall exposure hazard")
    primary_driver: str = Field(..., description="Main pollutant or factor driving exposure risk")
    
    # Explainable factor breakdown
    breakdown: List[RiskFactorContribution] = Field(
        default_factory=list,
        description="Detailed list of all quantified contributors to the risk score"
    )
    
    # Grounded recommendations
    activity_recommendations: List[ActivityRecommendation] = Field(
        default_factory=list,
        description="Specific activity guidance based on current exposure risk"
    )
    
    disclaimer: str = Field(
        default="This environmental intelligence score is for risk awareness and activity planning only. "
                "It does not constitute medical diagnosis or advice, nor does it guarantee protection against health effects.",
        description="Mandatory health disclaimer"
    )
