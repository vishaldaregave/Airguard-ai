"""
AirGuard AI - Milestone 5.2 Exposure Simulator & Personal Environmental Exposure Tests
Tests concentration-time exposure, estimated gross inhaled mass, activity profile validation,
duration boundaries, missing pollutant integrity, stale data handling, scenario comparison,
and API contracts.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.exposure import ActivityType
from app.engine.exposure_engine import (
    ACTIVITY_PROFILES,
    calculate_concentration_time_exposure,
    calculate_inhaled_mass,
    compute_all_pollutant_metrics,
    get_activity_profile,
)

client = TestClient(app)


# =========================================================================
# 1. CORE ENGINE & MATHEMATICAL FORMULATION TESTS
# =========================================================================

def test_concentration_time_exposure_calculation():
    """
    Verify concentration-time exposure formula:
    Exposure Index = Ambient Concentration × Duration (hours).
    Units: µg·h/m³ for particulate/gases, mg·h/m³ for Carbon Monoxide.
    """
    # 60 minutes = 1.0 hour at 120 µg/m³ PM2.5 -> 120.0 µg·h/m³
    exp_val, unit = calculate_concentration_time_exposure(120.0, 1.0, "PM2.5")
    assert exp_val == 120.0
    assert unit == "µg·h/m³"

    # 45 minutes = 0.75 hours at 200 µg/m³ PM10 -> 150.0 µg·h/m³
    exp_val, unit = calculate_concentration_time_exposure(200.0, 0.75, "PM10")
    assert exp_val == 150.0
    assert unit == "µg·h/m³"

    # 120 minutes = 2.0 hours at 2.5 mg/m³ CO -> 5.0 mg·h/m³
    exp_val, unit = calculate_concentration_time_exposure(2.5, 2.0, "CO")
    assert exp_val == 5.0
    assert unit == "mg·h/m³"


def test_estimated_inhaled_mass_calculation():
    """
    Verify estimated gross inhaled mass formula:
    Inhaled Mass = Ambient Concentration (C) × Ventilation Rate (V_E) × Duration (t).
    Units: µg for PM2.5/PM10, mg for CO.
    """
    # Walking (V_E = 1.2 m³/h), 1.0 hour, PM2.5 = 100.0 µg/m³ -> 100 * 1.2 * 1.0 = 120.0 µg
    mass_val, unit = calculate_inhaled_mass(100.0, 1.20, 1.0, "PM2.5")
    assert mass_val == 120.0
    assert unit == "µg"

    # Running (V_E = 2.8 m³/h), 0.5 hours (30 min), PM2.5 = 100.0 µg/m³ -> 100 * 2.8 * 0.5 = 140.0 µg
    mass_val, unit = calculate_inhaled_mass(100.0, 2.80, 0.5, "PM2.5")
    assert mass_val == 140.0
    assert unit == "µg"

    # Resting (V_E = 0.5 m³/h), 2.0 hours, CO = 3.0 mg/m³ -> 3.0 * 0.5 * 2.0 = 3.0 mg
    mass_val, unit = calculate_inhaled_mass(3.0, 0.50, 2.0, "CO")
    assert mass_val == 3.0
    assert unit == "mg"


def test_missing_pollutant_preserved_as_none_never_zero():
    """
    Missing pollutant data must remain None/unavailable and never silently become zero.
    """
    concentrations = {
        "PM2.5": 80.0,
        "PM10": None,  # Not monitored
        "NO2": 35.0,
        "CO": None,    # Not monitored
    }
    activity = get_activity_profile(ActivityType.WALKING)
    metrics = compute_all_pollutant_metrics(concentrations, activity, duration_minutes=60)

    # PM2.5 is available
    assert metrics["PM2.5"].is_available is True
    assert metrics["PM2.5"].ambient_concentration == 80.0
    assert metrics["PM2.5"].concentration_time_exposure == 80.0
    assert metrics["PM2.5"].estimated_inhaled_mass == 96.0  # 80 * 1.2 * 1.0

    # PM10 is missing
    assert metrics["PM10"].is_available is False
    assert metrics["PM10"].ambient_concentration is None
    assert metrics["PM10"].concentration_time_exposure is None
    assert metrics["PM10"].estimated_inhaled_mass is None

    # CO is missing
    assert metrics["CO"].is_available is False
    assert metrics["CO"].ambient_concentration is None
    assert metrics["CO"].estimated_inhaled_mass is None


def test_invalid_negative_values_rejected():
    """
    Negative concentrations or negative durations must raise ValueError.
    """
    with pytest.raises(ValueError, match="cannot be negative"):
        calculate_concentration_time_exposure(-10.0, 1.0, "PM2.5")

    with pytest.raises(ValueError, match="cannot be negative"):
        calculate_concentration_time_exposure(50.0, -0.5, "PM2.5")

    with pytest.raises(ValueError, match="cannot be negative"):
        calculate_inhaled_mass(-5.0, 1.2, 1.0, "PM2.5")

    with pytest.raises(ValueError, match="must be positive"):
        calculate_inhaled_mass(50.0, 0.0, 1.0, "PM2.5")


def test_activity_profiles_completeness_and_references():
    """
    All 5 standard activities (Resting, Commuting, Walking, Cycling, Running)
    must be defined with positive inhalation rates, MET equivalents, and references.
    """
    required_types = [
        ActivityType.RESTING,
        ActivityType.COMMUTING,
        ActivityType.WALKING,
        ActivityType.CYCLING,
        ActivityType.RUNNING,
    ]
    for act_type in required_types:
        assert act_type in ACTIVITY_PROFILES
        profile = ACTIVITY_PROFILES[act_type]
        assert profile.inhalation_rate_m3_h > 0.0
        assert profile.met_equivalent > 0.0
        assert len(profile.reference) > 10
        assert len(profile.description) > 10

    # Running ventilation rate must exceed Walking which exceeds Resting
    assert (
        ACTIVITY_PROFILES[ActivityType.RUNNING].inhalation_rate_m3_h
        > ACTIVITY_PROFILES[ActivityType.WALKING].inhalation_rate_m3_h
        > ACTIVITY_PROFILES[ActivityType.RESTING].inhalation_rate_m3_h
    )


# =========================================================================
# 2. BACKEND API ENDPOINT TESTS
# =========================================================================

def test_api_get_activity_profiles():
    """GET /api/v1/exposure/activity-profiles returns all 5 documented profiles."""
    res = client.get("/api/v1/exposure/activity-profiles")
    assert res.status_code == 200
    profiles = res.json()
    assert len(profiles) == 5
    types = {p["activity_type"] for p in profiles}
    assert types == {"resting", "commuting", "walking", "cycling", "running"}
    for p in profiles:
        assert "inhalation_rate_m3_h" in p
        assert "met_equivalent" in p
        assert "reference" in p


def test_api_simulate_custom_concentrations():
    """POST /api/v1/exposure/simulate with custom concentrations."""
    payload = {
        "activity_type": "running",
        "duration_minutes": 60,
        "custom_concentrations": {
            "PM2.5": 120.0,
            "PM10": 220.0,
            "NO2": 45.0,
            "CO": 1.8,
        },
    }
    res = client.post("/api/v1/exposure/simulate", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "COMPUTED"
    assert data["duration_minutes"] == 60
    assert data["duration_hours"] == 1.0
    # Running ventilation: 2.8 m3/h * 1.0 h = 2.8 m3
    assert data["total_inhaled_volume_m3"] == 2.8

    # Pollutant metrics
    pols = data["pollutants"]
    assert "PM2.5" in pols
    pm25 = pols["PM2.5"]
    assert pm25["ambient_concentration"] == 120.0
    assert pm25["concentration_time_exposure"] == 120.0
    assert pm25["exposure_unit"] == "µg·h/m³"
    # Inhaled mass: 120 µg/m3 * 2.8 m3/h * 1h = 336.0 µg
    assert pm25["estimated_inhaled_mass"] == 336.0
    assert pm25["mass_unit"] == "µg"

    # CO metrics in mg
    co = pols["CO"]
    assert co["ambient_concentration"] == 1.8
    assert co["exposure_unit"] == "mg·h/m³"
    assert co["mass_unit"] == "mg"
    # 1.8 * 2.8 * 1.0 = 5.04 mg
    assert co["estimated_inhaled_mass"] == pytest.approx(5.04, abs=0.01)

    # Disclaimers present
    assert "does not constitute clinical" in data["disclaimer"]
    assert "Methodology" in data["calculation_methodology"]


def test_api_simulate_duration_boundary_validation():
    """POST /api/v1/exposure/simulate rejects duration < 15 or > 480 minutes."""
    # Under 15 minutes
    res_under = client.post(
        "/api/v1/exposure/simulate",
        json={"activity_type": "walking", "duration_minutes": 10},
    )
    assert res_under.status_code == 422

    # Over 480 minutes (8 hours)
    res_over = client.post(
        "/api/v1/exposure/simulate",
        json={"activity_type": "walking", "duration_minutes": 500},
    )
    assert res_over.status_code == 422


def test_api_compare_scenarios():
    """
    POST /api/v1/exposure/compare:
    Compare Scenario A (Walking 60 min) vs Scenario B (Running 60 min).
    """
    payload = {
        "scenario_a": {
            "activity_type": "walking",
            "duration_minutes": 60,
            "custom_concentrations": {"PM2.5": 100.0, "PM10": 180.0},
        },
        "scenario_b": {
            "activity_type": "running",
            "duration_minutes": 60,
            "custom_concentrations": {"PM2.5": 100.0, "PM10": 180.0},
        },
        "label_a": "Morning Walk",
        "label_b": "Morning Run",
    }
    res = client.post("/api/v1/exposure/compare", json=payload)
    assert res.status_code == 200
    data = res.json()

    assert "scenario_a" in data
    assert "scenario_b" in data
    assert "deltas" in data

    deltas = data["deltas"]
    pm25_delta = deltas["PM2.5"]

    # Scenario A (Walking 1.2 m3/h): 100 * 1.2 * 1h = 120 µg
    # Scenario B (Running 2.8 m3/h): 100 * 2.8 * 1h = 280 µg
    # Delta mass: 280 - 120 = +160 µg (+133.3%)
    assert pm25_delta["scenario_a_inhaled_mass"] == 120.0
    assert pm25_delta["scenario_b_inhaled_mass"] == 280.0
    assert pm25_delta["delta_inhaled_mass"] == 160.0
    assert pm25_delta["percent_change_inhaled_mass"] == pytest.approx(133.3, abs=0.2)

    # Physical comparison narrative present without clinical claims
    assert "Physical Comparison Analysis" in data["physical_comparison_summary"]
    assert "Ventilation Ratio" in data["physical_comparison_summary"]


def test_api_explain_exposure():
    """POST /api/v1/exposure/explain returns structured explanation."""
    # First get simulation response
    sim_res = client.post(
        "/api/v1/exposure/simulate",
        json={
            "activity_type": "cycling",
            "duration_minutes": 45,
            "custom_concentrations": {"PM2.5": 150.0, "PM10": 250.0},
        },
    ).json()

    explain_payload = {
        "simulation": sim_res,
        "user_query": "Is it safe to cycle today?",
    }
    res = client.post("/api/v1/exposure/explain", json=explain_payload)
    assert res.status_code == 200
    data = res.json()

    assert "narrative" in data
    assert len(data["key_takeaways"]) >= 2
    assert len(data["protective_suggestions"]) >= 1
    assert "does not constitute clinical" in data["disclaimer"]
