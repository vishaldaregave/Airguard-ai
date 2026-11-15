import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/observation_model.dart';
import '../../domain/models/risk_assessment_model.dart';
import '../../domain/models/station_model.dart';

class EnvironmentalState {
  final bool isLoading;
  final String? errorMessage;
  final UserLocationResult? userLocation;
  final List<MonitoringStationSummary> nearbyStations;
  final MonitoringStationSummary? selectedStation;
  final AssessmentResponse? currentAssessment;
  final List<ProviderStatusItem> providerStatuses;

  EnvironmentalState({
    this.isLoading = false,
    this.errorMessage,
    this.userLocation,
    this.nearbyStations = const [],
    this.selectedStation,
    this.currentAssessment,
    this.providerStatuses = const [],
  });

  EnvironmentalObservation? get currentObservation =>
      currentAssessment?.observation;

  EnvironmentalState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserLocationResult? userLocation,
    List<MonitoringStationSummary>? nearbyStations,
    MonitoringStationSummary? selectedStation,
    AssessmentResponse? currentAssessment,
    List<ProviderStatusItem>? providerStatuses,
  }) {
    return EnvironmentalState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      userLocation: userLocation ?? this.userLocation,
      nearbyStations: nearbyStations ?? this.nearbyStations,
      selectedStation: selectedStation ?? this.selectedStation,
      currentAssessment: currentAssessment ?? this.currentAssessment,
      providerStatuses: providerStatuses ?? this.providerStatuses,
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
      // 1. Acquire GPS or fallback location
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
        userLocation: locationResult,
        nearbyStations: stations,
        selectedStation: activeStation,
        currentAssessment: assessment,
        providerStatuses: statuses,
      );
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
        selectedStation: station,
        currentAssessment: assessment,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve measurements for ${station.stationName}: $e',
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
        userLocation: locationResult,
        nearbyStations: stations,
        selectedStation: activeStation,
        currentAssessment: assessment,
      );
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
}

final environmentalControllerProvider =
    StateNotifierProvider<EnvironmentalController, EnvironmentalState>((ref) {
  final repo = ref.watch(environmentalRepositoryProvider);
  final locService = ref.watch(locationServiceProvider);
  return EnvironmentalController(repo, locService);
});
