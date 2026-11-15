"""
AirGuard AI - AI Intelligence & Explainer Endpoints
Generates scientifically grounded atmospheric explanations and activity guidance.
"""
from fastapi import APIRouter, HTTPException, status

from app.schemas.ai_explanation import AIExplanationRequest, AIExplanationResponse
from app.services.ai_explainer import ai_explainer_service

router = APIRouter()


@router.post(
    "/explain",
    response_model=AIExplanationResponse,
    summary="Generate AI-Powered Environmental Explanation",
    description=(
        "Analyzes verified structured environmental inputs and returns grounded scientific answers to the "
        "6 core inquiries: atmospheric dynamics, primary pollutant driver, elevation causes, "
        "outdoor activity impact, practical precautions, and historical comparisons. "
        "Includes deterministic expert fallback if external LLM APIs are unconfigured."
    ),
)
async def explain_environmental_condition(
    request: AIExplanationRequest,
) -> AIExplanationResponse:
    try:
        return await ai_explainer_service.generate_explanation(request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI explanation generation error: {str(e)}",
        )
