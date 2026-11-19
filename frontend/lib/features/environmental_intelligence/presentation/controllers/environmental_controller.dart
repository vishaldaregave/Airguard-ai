import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/observation_model.dart';
import '../../domain/models/risk_assessment_model.dart';
import '../../domain/models/station_model.dart';
import '../../domain/models/forecast_model.dart';
import '../../domain/models/ai_explanation_model.dart';

class EnvironmentalState {
  final bool isLoading;
  final String? errorMessage;
  final UserLocationResult? userLocation;
  final List<MonitoringStationSummary> nearbyStations;
  final MonitoringStationSummary? selectedStation;
  final AssessmentResponse? currentAssessment;
  final List<ProviderStatusItem> providerStatuses;

  // Milestone 3 additions
  final ForecastCurrentResponse? forecast;
  final AIExplanationResponse? aiExplanation;
  final int selectedHorizonHours;
  final bool isForecastLoading;
  final bool isAILoading;
  final String? forecastError;
  final String? aiError;

  EnvironmentalState({
    this.isLoading = false,
    this.errorMessage,
    this.userLocation,
    this.nearbyStations = const [],
    this.selectedStation,
    this.currentAssessment,
    this.providerStatuses = const [],
    this.forecast,
    this.aiExplanation,
    this.selectedHorizonHours = 3,
    this.isForecastLoading = false,
    this.isAILoading = false,
    this.forecastError,
    this.aiError,
  });

  EnvironmentalObservation? get currentObservation =>
      currentAssessment?.observation;

  HorizonForecastStep? get selectedForecastStep {
    if (forecast == null || forecast!.forecasts.isEmpty) return null;
    return forecast!.forecasts.firstWhere(
      (f) => f.horizonHours == selectedHorizonHours,
      orElse: () => forecast!.forecasts.first,
    );
  }

  EnvironmentalState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserLocationResult? userLocation,
    List<MonitoringStationSummary>? nearbyStations,
    MonitoringStationSummary? selectedStation,
    AssessmentResponse? currentAssessment,
    List<ProviderStatusItem>? providerStatuses,
    ForecastCurrentResponse? forecast,
    AIExplanationResponse? aiExplanation,
    int? selectedHorizonHours,
    bool? isForecastLoading,
    bool? isAILoading,
    String? forecastError,
    String? aiError,
    bool clearError = false,
  }) {
    return EnvironmentalState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userLocation: userLocation ?? this.userLocation,
      nearbyStations: nearbyStations ?? this.nearbyStations,
      selectedStation: selectedStation ?? this.selectedStation,
      currentAssessment: currentAssessment ?? this.currentAssessment,
      providerStatuses: providerStatuses ?? this.providerStatuses,
      forecast: forecast ?? this.forecast,
      aiExplanation: aiExplanation ?? this.aiExplanation,
      selectedHorizonHours: selectedHorizonHours ?? this.selectedHorizonHours,
      isForecastLoading: isForecastLoading ?? this.isForecastLoading,
      isAILoading: isAILoading ?? this.isAILoading,
      forecastError: forecastError ?? this.forecastError,
      aiError: aiError ?? this.aiError,
    );
  }
}

class EnvironmentalController extends StateNotifier<EnvironmentalState> {
  final EnvironmentalRepository _repository;
  final LocationService _locationService;

  EnvironmentalController(this._repository, this._locationService)
      : super(EnvironmentalState()) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Acquire GPS or high-accuracy IP location
      final locationResult = await _locationService.determinePosition();
      
      // 2. Discover nearby stations across providers
      final stations = await _repository.getNearbyStations(
        locationResult.latitude,
        locationResult.longitude,
        radiusKm: 30.0,
      );

      // 3. Retrieve live assessment at coordinates
      final assessment = await _repository.getCurrentAirQuality(
        lat: locationResult.latitude,
        lon: locationResult.longitude,
      );

      // 4. Retrieve provider status
      final statuses = await _repository.getProvidersStatus();

      final activeStation = assessment.station ?? (stations.isNotEmpty ? stations.first : null);

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        userLocation: locationResult,
        nearbyStations: stations,
        selectedStation: activeStation,
        currentAssessment: assessment,
        providerStatuses: statuses,
      );

      // 5. Asynchronously trigger Forecast and AI Explanation
      await _fetchForecastAndExplanation(assessment, activeStation?.stationId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize environmental intelligence: $e',
      );
    }
  }

  Future<void> selectStation(MonitoringStationSummary station) async {
    state = state.copyWith(isLoading: true, selectedStation: station, errorMessage: null);
    try {
      final userLat = state.userLocation?.latitude;
      final userLon = state.userLocation?.longitude;

      final assessment = await _repository.getCurrentAirQuality(
        stationId: station.stationId,
        lat: userLat,
        lon: userLon,
      );

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        selectedStation: station,
        currentAssessment: assessment,
      );

      await _fetchForecastAndExplanation(assessment, station.stationId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve measurements for ${station.stationName}: $e',
      );
    }
  }

  /// Changes the user's location to any selected city or coordinates
  Future<void> changeLocation(
    double lat,
    double lon, {
    String? cityName,
    String? stateName,
    String? countryName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final loc = UserLocationResult(
        latitude: lat,
        longitude: lon,
        isGpsLive: false,
        isUserSelected: true,
        statusMessage: 'Location set to ${cityName ?? "custom coordinates"}',
        cityName: cityName,
        stateName: stateName,
        countryName: countryName,
      );

      final stations = await _repository.getNearbyStations(lat, lon, radiusKm: 30.0);
      final assessment = await _repository.getCurrentAirQuality(lat: lat, lon: lon);
      final activeStation = assessment.station ?? (stations.isNotEmpty ? stations.first : null);

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        userLocation: loc,
        nearbyStations: stations,
        selectedStation: activeStation,
        currentAssessment: assessment,
      );

      await _fetchForecastAndExplanation(assessment, activeStation?.stationId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update location: $e',
      );
    }
  }

  Future<void> locateMe() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final locationResult = await _locationService.determinePosition();
      final stations = await _repository.getNearbyStations(
        locationResult.latitude,
        locationResult.longitude,
        radiusKm: 30.0,
      );
      final assessment = await _repository.getCurrentAirQuality(
        lat: locationResult.latitude,
        lon: locationResult.longitude,
      );
      final activeStation = assessment.station ?? (stations.isNotEmpty ? stations.first : null);

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        userLocation: locationResult,
        nearbyStations: stations,
        selectedStation: activeStation,
        currentAssessment: assessment,
      );

      await _fetchForecastAndExplanation(assessment, activeStation?.stationId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update location: $e',
      );
    }
  }

  Future<void> refreshCurrent() async {
    if (state.selectedStation != null) {
      await selectStation(state.selectedStation!);
    } else {
      await locateMe();
    }
  }

  void selectForecastHorizon(int hours) {
    state = state.copyWith(selectedHorizonHours: hours);
  }

  Future<void> _fetchForecastAndExplanation(
    AssessmentResponse assessment,
    String? stationId,
  ) async {
    // Forecast fetch
    state = state.copyWith(isForecastLoading: true, forecastError: null);
    try {
      final forecastRes = await _repository.getForecast(
        stationId: stationId,
        lat: state.userLocation?.latitude,
        lon: state.userLocation?.longitude,
      );
      state = state.copyWith(forecast: forecastRes, isForecastLoading: false);
    } catch (e) {
      state = state.copyWith(isForecastLoading: false, forecastError: e.toString());
    }

    // AI Explanation fetch
    state = state.copyWith(isAILoading: true, aiError: null);
    try {
      final explRes = await _repository.getAIExplanation(assessment: assessment);
      state = state.copyWith(aiExplanation: explRes, isAILoading: false);
    } catch (e) {
      state = state.copyWith(isAILoading: false, aiError: e.toString());
    }
  }
}

final environmentalControllerProvider =
    StateNotifierProvider<EnvironmentalController, EnvironmentalState>((ref) {
  final repo = ref.watch(environmentalRepositoryProvider);
  final loc = ref.watch(locationServiceProvider);
  return EnvironmentalController(repo, loc);
});
