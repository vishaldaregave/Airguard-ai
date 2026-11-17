"""
AirGuard AI - Exposure Intelligence Orchestration Service
Coordinates environmental telemetry, spatial interpolation, forecasting,
and physical ventilation models to compute personal environmental exposure.
"""
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple

from app.core.config import settings
from app.engine.cpcb_aqi import calculate_cpcb_aqi
from app.engine.exposure_engine import (
    ACTIVITY_PROFILES,
    CALCULATION_METHODOLOGY_NOTE,
    EXPOSURE_NON_MEDICAL_DISCLAIMER,
    compute_all_pollutant_metrics,
    compare_scenarios as engine_compare_scenarios,
    get_activity_profile,
)
from app.engine.spatial_interpolator import spatial_interpolator
from app.engine.forecasting import forecast_model
from app.schemas.pollutant import (
    DataSourceType,
    EnvironmentalObservationInput,
    LocationCoordinate,
)
from app.schemas.exposure import (
    ActivityProfile,
    ActivityType,
    CompareExposureRequest,
    ExposureComparisonResponse,
    ExposureExplanationRequest,
    ExposureExplanationResponse,
    ExposureSimulationResponse,
    PollutantComparisonDelta,
    ScenarioComparisonItem,
    SimulateExposureRequest,
)
from app.services.environmental_service import environmental_service
from app.services.geo_intelligence_service import geo_intelligence_service
from app.services.history_service import history_service


class ExposureService:
    """
    Orchestration service for environmental exposure simulations.
    Pure physical calculations, zero medical diagnosis claims, strict provenance handling.
    """

    def __init__(self):
        pass

    def get_activity_profiles(self) -> List[ActivityProfile]:
        """Returns the list of supported, documented activity profiles."""
        return list(ACTIVITY_PROFILES.values())

    async def simulate_exposure(
        self,
        request: SimulateExposureRequest,
    ) -> ExposureSimulationResponse:
        """
        Executes a deterministic exposure simulation based on physical parameters
        and live, interpolated, or forecast environmental data.
        """
        now_utc = datetime.now(timezone.utc)
        activity = get_activity_profile(request.activity_type)
        duration_hours = request.duration_minutes / 60.0
        total_inhaled_vol = round(activity.inhalation_rate_m3_h * duration_hours, 2)

        # ---------------------------------------------------------------------
        # 1. Custom Concentrations (What-If Simulation)
        # ---------------------------------------------------------------------
        if request.custom_concentrations:
            concentrations: Dict[str, Optional[float]] = {}
            for k, v in request.custom_concentrations.items():
                pol_key = k.upper().replace("_", ".")
                concentrations[pol_key] = float(v) if v is not None and v >= 0 else None

            synth_coord = LocationCoordinate(
                latitude=request.latitude or 28.6139,
                longitude=request.longitude or 77.2090,
                city="Custom Scenario",
                country="India",
            )
            synth_obs = EnvironmentalObservationInput(
                station_id="CUSTOM-SCENARIO",
                station_name="Custom User-Defined Environmental Scenario",
                location=synth_coord,
                timestamp=now_utc,
                provider="AirGuard Custom Simulator",
                data_source_type=DataSourceType.ESTIMATED,
                pm2_5=concentrations.get("PM2.5"),
                pm10=concentrations.get("PM10"),
                no2=concentrations.get("NO2"),
                so2=concentrations.get("SO2"),
                co=concentrations.get("CO"),
                o3=concentrations.get("O3"),
                nh3=concentrations.get("NH3"),
                pb=concentrations.get("PB"),
            )
            cpcb_res = calculate_cpcb_aqi(synth_obs)
            pollutant_metrics = compute_all_pollutant_metrics(concentrations, activity, request.duration_minutes)

            return ExposureSimulationResponse(
                status="COMPUTED",
                activity=activity,
                duration_minutes=request.duration_minutes,
                duration_hours=round(duration_hours, 2),
                total_inhaled_volume_m3=total_inhaled_vol,
                data_source_type=DataSourceType.ESTIMATED,
                location_name="Custom Simulation Scenario",
                latitude=request.latitude,
                longitude=request.longitude,
                pollutants=pollutant_metrics,
                cpcb_aqi=cpcb_res.overall_aqi,
                cpcb_category=cpcb_res.category.value if cpcb_res.category else None,
                prominent_pollutant=(
                    cpcb_res.prominent_pollutant.value
                    if hasattr(cpcb_res.prominent_pollutant, "value")
                    else cpcb_res.prominent_pollutant
                ),
                is_forecast=False,
                is_interpolated=False,
                spatial_uncertainty_score=None,
                calculation_methodology=CALCULATION_METHODOLOGY_NOTE,
                disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER,
                timestamp=now_utc,
            )

        # ---------------------------------------------------------------------
        # 2. Forecast Window Simulation
        # ---------------------------------------------------------------------
        if request.use_forecast:
            lat = request.latitude or 28.6139
            lon = request.longitude or 77.2090
            st_id = request.station_id or f"GRID-{lat:.2f}-{lon:.2f}"

            # Fetch baseline current air quality
            curr_res = await environmental_service.get_current_air_quality(
                station_id=request.station_id, latitude=request.latitude, longitude=request.longitude
            )
            if not curr_res or not curr_res.observation:
                return self._create_insufficient_data_response(
                    activity, request.duration_minutes, "No environmental data available to seed forecast exposure."
                )

            current_obs = curr_res.observation
            history_data = await history_service.get_history(st_id, hours=72)
            if len(history_data) < 24:
                # Seed history if needed
                await history_service.seed_history_if_needed(st_id, lat, lon)
                history_data = await history_service.get_history(st_id, hours=72)

            forecast_res = forecast_model.predict_multi_horizon(history_data, current_obs)

            # Determine window hours: [offset, offset + duration_hours]
            start_h = request.forecast_start_offset_hours
            end_h = start_h + duration_hours

            # Approximate time-weighted forecast concentration across target horizon steps
            forecast_concentrations: Dict[str, Optional[float]] = {}
            for pol in ["PM2.5", "PM10", "NO2", "SO2", "CO", "O3"]:
                # Select nearest forecast step(s) within the exposure window
                relevant_vals: List[float] = []
                for step in forecast_res.forecast_steps:
                    h = step.horizon_hours
                    # If step is within or close to target window
                    if start_h <= h <= max(end_h, 1):
                        p_pred = step.pollutants.get(pol)
                        if p_pred and p_pred.predicted_value is not None:
                            relevant_vals.append(p_pred.predicted_value)

                if relevant_vals:
                    forecast_concentrations[pol] = round(sum(relevant_vals) / len(relevant_vals), 1)
                else:
                    # Fallback to current obs value if horizon not matched
                    cur_val = getattr(current_obs, pol.lower().replace(".", "_"), None)
                    forecast_concentrations[pol] = cur_val

            # Compute CPCB forecast AQI on estimated concentrations
            synth_forecast_obs = EnvironmentalObservationInput(
                station_id=f"FORECAST-{st_id}",
                station_name=f"Forecast Window (+{start_h}h to +{end_h:.1f}h) at {current_obs.station_name}",
                location=current_obs.location,
                timestamp=now_utc + timedelta(hours=start_h),
                provider="AirGuard Predictive Forecast Engine",
                data_source_type=DataSourceType.FORECAST,
                pm2_5=forecast_concentrations.get("PM2.5"),
                pm10=forecast_concentrations.get("PM10"),
                no2=forecast_concentrations.get("NO2"),
                so2=forecast_concentrations.get("SO2"),
                co=forecast_concentrations.get("CO"),
                o3=forecast_concentrations.get("O3"),
            )
            cpcb_res = calculate_cpcb_aqi(synth_forecast_obs)
            pollutant_metrics = compute_all_pollutant_metrics(forecast_concentrations, activity, request.duration_minutes)

            loc_name = f"Forecast Window (+{start_h}h to +{end_h:.1f}h): {current_obs.station_name or 'Query Location'}"
            return ExposureSimulationResponse(
                status="COMPUTED",
                activity=activity,
                duration_minutes=request.duration_minutes,
                duration_hours=round(duration_hours, 2),
                total_inhaled_volume_m3=total_inhaled_vol,
                data_source_type=DataSourceType.FORECAST,
                location_name=loc_name,
                latitude=current_obs.location.latitude,
                longitude=current_obs.location.longitude,
                pollutants=pollutant_metrics,
                cpcb_aqi=cpcb_res.overall_aqi,
                cpcb_category=cpcb_res.category.value if cpcb_res.category else None,
                prominent_pollutant=(
                    cpcb_res.prominent_pollutant.value
                    if hasattr(cpcb_res.prominent_pollutant, "value")
                    else cpcb_res.prominent_pollutant
                ),
                is_forecast=True,
                is_interpolated=False,
                spatial_uncertainty_score=None,
                calculation_methodology=CALCULATION_METHODOLOGY_NOTE + "\nForecast: Autoregressive ridge regression multi-horizon projection.",
                disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER + " Projected from forecast environmental model; actual future exposure may vary.",
                timestamp=now_utc,
            )

        # ---------------------------------------------------------------------
        # 3. Live or Spatially Interpolated Observation
        # ---------------------------------------------------------------------
        is_interpolated = False
        spatial_uncertainty: Optional[float] = None
        obs: Optional[EnvironmentalObservationInput] = None
        station_name: str = "Query Location"

        # Check if coordinates given and interpolation requested
        if request.latitude is not None and request.longitude is not None and request.use_interpolation:
            # Query nearby stations
            obs_list = await geo_intelligence_service.get_geo_observations(
                request.latitude, request.longitude, radius_km=50.0, include_demo=request.allow_demo
            )
            # Check IDW eligibility
            if len(obs_list) >= 3:
                interp_res = spatial_interpolator.interpolate(
                    request.latitude, request.longitude, obs_list, allow_demo=request.allow_demo
                )
                if interp_res.status.value == "INTERPOLATED":
                    is_interpolated = True
                    spatial_uncertainty = interp_res.spatial_uncertainty_score
                    station_name = f"Spatially Interpolated ({request.latitude:.3f}°N, {request.longitude:.3f}°E)"

                    # Extract concentrations from interpolated pollutants
                    concentrations = {}
                    for p_key, p_val in interp_res.pollutants.items():
                        pol_display = p_key.upper().replace("_", ".")
                        concentrations[pol_display] = p_val.estimated_value

                    pollutant_metrics = compute_all_pollutant_metrics(concentrations, activity, request.duration_minutes)
                    return ExposureSimulationResponse(
                        status="COMPUTED",
                        activity=activity,
                        duration_minutes=request.duration_minutes,
                        duration_hours=round(duration_hours, 2),
                        total_inhaled_volume_m3=total_inhaled_vol,
                        data_source_type=DataSourceType.ESTIMATED,
                        location_name=station_name,
                        latitude=request.latitude,
                        longitude=request.longitude,
                        pollutants=pollutant_metrics,
                        cpcb_aqi=interp_res.interpolated_aqi,
                        cpcb_category=interp_res.cpcb_category,
                        prominent_pollutant=interp_res.dominant_pollutant,
                        is_forecast=False,
                        is_interpolated=True,
                        spatial_uncertainty_score=spatial_uncertainty,
                        calculation_methodology=CALCULATION_METHODOLOGY_NOTE + "\nSpatial Interpolation: Inverse Distance Weighting (IDW, power=2.0, R<=50km).",
                        disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER,
                        timestamp=now_utc,
                    )

        # Direct observation retrieval
        curr_res = await environmental_service.get_current_air_quality(
            station_id=request.station_id,
            latitude=request.latitude,
            longitude=request.longitude,
        )

        if not curr_res or not curr_res.observation:
            return self._create_insufficient_data_response(
                activity, request.duration_minutes, "No monitoring station or atmospheric model data found for location."
            )

        obs = curr_res.observation
        station_name = obs.station_name or obs.station_id or "Monitoring Location"

        # Check staleness
        status_code = "COMPUTED"
        if curr_res.is_stale:
            status_code = "STALE_DATA"

        concentrations = {
            "PM2.5": obs.pm2_5,
            "PM10": obs.pm10,
            "NO2": obs.no2,
            "SO2": obs.so2,
            "CO": obs.co,
            "O3": obs.o3,
            "NH3": obs.nh3,
            "PB": obs.pb,
        }

        pollutant_metrics = compute_all_pollutant_metrics(concentrations, activity, request.duration_minutes)
        aqi_res = curr_res.aqi_result

        return ExposureSimulationResponse(
            status=status_code,
            activity=activity,
            duration_minutes=request.duration_minutes,
            duration_hours=round(duration_hours, 2),
            total_inhaled_volume_m3=total_inhaled_vol,
            data_source_type=obs.data_source_type,
            location_name=station_name,
            latitude=obs.location.latitude,
            longitude=obs.location.longitude,
            pollutants=pollutant_metrics,
            cpcb_aqi=aqi_res.overall_aqi if aqi_res else None,
            cpcb_category=aqi_res.category.value if aqi_res and aqi_res.category else None,
            prominent_pollutant=(
                aqi_res.prominent_pollutant.value
                if aqi_res and hasattr(aqi_res.prominent_pollutant, "value")
                else (aqi_res.prominent_pollutant if aqi_res else None)
            ),
            is_forecast=False,
            is_interpolated=False,
            spatial_uncertainty_score=None,
            calculation_methodology=CALCULATION_METHODOLOGY_NOTE,
            disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER + (" (Warning: environmental observation is older than 120 minutes.)" if curr_res.is_stale else ""),
            timestamp=now_utc,
        )

    def _create_insufficient_data_response(
        self,
        activity: ActivityProfile,
        duration_minutes: int,
        message: str,
    ) -> ExposureSimulationResponse:
        now_utc = datetime.now(timezone.utc)
        duration_hours = duration_minutes / 60.0
        return ExposureSimulationResponse(
            status="INSUFFICIENT_DATA",
            activity=activity,
            duration_minutes=duration_minutes,
            duration_hours=round(duration_hours, 2),
            total_inhaled_volume_m3=round(activity.inhalation_rate_m3_h * duration_hours, 2),
            data_source_type=DataSourceType.ESTIMATED,
            location_name="Unknown Location",
            latitude=None,
            longitude=None,
            pollutants={},
            cpcb_aqi=None,
            cpcb_category=None,
            prominent_pollutant=None,
            is_forecast=False,
            is_interpolated=False,
            spatial_uncertainty_score=100.0,
            calculation_methodology=CALCULATION_METHODOLOGY_NOTE,
            disclaimer=f"{EXPOSURE_NON_MEDICAL_DISCLAIMER} Note: {message}",
            timestamp=now_utc,
        )

    async def compare_scenarios(
        self,
        request: CompareExposureRequest,
    ) -> ExposureComparisonResponse:
        """
        Executes and compares two distinct exposure scenarios (duration, activity, location, or forecast).
        """
        now_utc = datetime.now(timezone.utc)
        sim_a = await self.simulate_exposure(request.scenario_a)
        sim_b = await self.simulate_exposure(request.scenario_b)

        deltas, physical_summary = engine_compare_scenarios(
            sim_a, sim_b, label_a=request.label_a, label_b=request.label_b
        )

        return ExposureComparisonResponse(
            scenario_a=ScenarioComparisonItem(
                scenario_id="scenario_a",
                label=request.label_a,
                simulation=sim_a,
            ),
            scenario_b=ScenarioComparisonItem(
                scenario_id="scenario_b",
                label=request.label_b,
                simulation=sim_b,
            ),
            deltas=deltas,
            physical_comparison_summary=physical_summary,
            disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER + " Comparisons highlight physical intake differences; they do not establish medical safety.",
            timestamp=now_utc,
        )

    async def explain_exposure(
        self,
        request: ExposureExplanationRequest,
    ) -> ExposureExplanationResponse:
        """
        Produces an explainable atmospheric and physiological ventilation narrative
        clarifying duration vs exertion trade-offs and protective measures.
        """
        now_utc = datetime.now(timezone.utc)
        sim = request.simulation
        act = sim.activity
        dur_m = sim.duration_minutes
        vol = sim.total_inhaled_volume_m3

        pm25_metric = sim.pollutants.get("PM2.5")
        pm25_conc = pm25_metric.ambient_concentration if pm25_metric else None
        pm25_mass = pm25_metric.estimated_inhaled_mass if pm25_metric else None

        # Exertion factor vs basal resting (0.50 m3/h)
        exertion_mult = round(act.inhalation_rate_m3_h / 0.50, 1)

        narrative = (
            f"During {dur_m} minutes of {act.display_name.lower()} at {sim.location_name}, your respiratory system "
            f"will ventilate an estimated {vol:.2f} m³ of ambient air (ventilation rate: {act.inhalation_rate_m3_h} m³/h, "
            f"{exertion_mult}x resting baseline). "
        )

        if pm25_conc is not None and pm25_mass is not None:
            narrative += (
                f"With ambient PM2.5 at {pm25_conc:.1f} µg/m³, this equates to a cumulative concentration-time exposure of "
                f"{pm25_metric.concentration_time_exposure:.1f} µg·h/m³ and an estimated gross inhaled PM2.5 mass of {pm25_mass:.1f} µg. "
            )

        if sim.cpcb_aqi:
            narrative += f"Ambient air quality is indexed at {sim.cpcb_aqi} ({sim.cpcb_category or 'Moderate'}). "

        # Takeaways
        takeaways = [
            f"Physical Activity Multiplier: {act.display_name} increases air intake {exertion_mult}x relative to sedentary rest.",
            f"Duration Proportionality: Inhaled mass scales linearly with time. A 30-minute session halves gross pollutant intake compared to 60 minutes.",
            f"Total Inhaled Volume: {vol:.2f} m³ of ambient air breathed over {dur_m} minutes.",
        ]

        # Protective suggestions
        suggestions: List[str] = []
        if sim.cpcb_aqi and sim.cpcb_aqi > 200:
            suggestions.append("Shift vigorous aerobic exertion (e.g. running or cycling) to indoor filtered spaces (HEPA).")
            suggestions.append("If outdoor activity is required, consider reducing duration or moderating pace to walking to lower minute ventilation.")
        elif sim.cpcb_aqi and sim.cpcb_aqi > 100:
            suggestions.append("Schedule outdoor endurance sessions during midday when convective boundary layer dispersion is higher.")
            suggestions.append("Avoid major traffic corridors where localized microenvironment concentrations of NO2 and ultrafine particles peak.")
        else:
            suggestions.append("Current ambient conditions are suitable for normal outdoor aerobic exercise.")

        return ExposureExplanationResponse(
            narrative=narrative,
            key_takeaways=takeaways,
            protective_suggestions=suggestions,
            methodology_note="Ventilation rates follow US EPA Exposure Factors Handbook (2011). Inhaled mass represents gross inhaled quantity, not retained pulmonary dose.",
            disclaimer=EXPOSURE_NON_MEDICAL_DISCLAIMER,
            provider="AirGuard Environmental Intelligence Engine",
            timestamp=now_utc,
        )


# Singleton instance
exposure_service = ExposureService()
