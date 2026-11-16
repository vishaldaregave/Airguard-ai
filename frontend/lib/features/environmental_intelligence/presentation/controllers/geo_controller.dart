import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/geo_models.dart';

class GeoState {
  final bool isLoading;
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final String selectedPollutant;
  final List<GeoStationModel> stations;
  final List<GeoObservationModel> observations;
  final List<HotspotClusterModel> hotspots;
  final GeoCoverageModel? coverage;
  final GeoObservationModel? selectedObservation;
  final GeoStationModel? selectedStation;
  final SpatialInterpolationModel? activeInterpolation;
  final bool isInterpolating;
  final String? errorMessage;
  final bool showHotspots;
  final bool showModelGrid;
  final bool allowDemo;

  const GeoState({
    this.isLoading = false,
    this.centerLat = 28.6139,
    this.centerLon = 77.2090,
    this.radiusKm = 50.0,
    this.selectedPollutant = 'AQI',
    this.stations = const [],
    this.observations = const [],
    this.hotspots = const [],
    this.coverage,
    this.selectedObservation,
    this.selectedStation,
    this.activeInterpolation,
    this.isInterpolating = false,
    this.errorMessage,
    this.showHotspots = true,
    this.showModelGrid = true,
    this.allowDemo = true,
  });

  GeoState copyWith({
    bool? isLoading,
    double? centerLat,
    double? centerLon,
    double? radiusKm,
    String? selectedPollutant,
    List<GeoStationModel>? stations,
    List<GeoObservationModel>? observations,
    List<HotspotClusterModel>? hotspots,
    GeoCoverageModel? coverage,
    GeoObservationModel? selectedObservation,
    GeoStationModel? selectedStation,
    SpatialInterpolationModel? activeInterpolation,
    bool? isInterpolating,
    String? errorMessage,
    bool? showHotspots,
    bool? showModelGrid,
    bool? allowDemo,
    bool clearSelectedObservation = false,
    bool clearSelectedStation = false,
    bool clearInterpolation = false,
  }) {
    return GeoState(
      isLoading: isLoading ?? this.isLoading,
      centerLat: centerLat ?? this.centerLat,
      centerLon: centerLon ?? this.centerLon,
      radiusKm: radiusKm ?? this.radiusKm,
      selectedPollutant: selectedPollutant ?? this.selectedPollutant,
      stations: stations ?? this.stations,
      observations: observations ?? this.observations,
      hotspots: hotspots ?? this.hotspots,
      coverage: coverage ?? this.coverage,
      selectedObservation: clearSelectedObservation
          ? null
          : (selectedObservation ?? this.selectedObservation),
      selectedStation: clearSelectedStation
          ? null
          : (selectedStation ?? this.selectedStation),
      activeInterpolation: clearInterpolation
          ? null
          : (activeInterpolation ?? this.activeInterpolation),
      isInterpolating: isInterpolating ?? this.isInterpolating,
      errorMessage: errorMessage,
      showHotspots: showHotspots ?? this.showHotspots,
      showModelGrid: showModelGrid ?? this.showModelGrid,
      allowDemo: allowDemo ?? this.allowDemo,
    );
  }
}

final geoControllerProvider =
    StateNotifierProvider<GeoController, GeoState>((ref) {
  final repository = ref.watch(environmentalRepositoryProvider);
  return GeoController(repository);
});

class GeoController extends StateNotifier<GeoState> {
  final EnvironmentalRepository _repository;

  GeoController(this._repository) : super(const GeoState()) {
    loadGeographicData();
  }

  Future<void> loadGeographicData({
    double? lat,
    double? lon,
    double? radiusKm,
  }) async {
    final targetLat = lat ?? state.centerLat;
    final targetLon = lon ?? state.centerLon;
    final targetRadius = radiusKm ?? state.radiusKm;

    state = state.copyWith(
      isLoading: true,
      centerLat: targetLat,
      centerLon: targetLon,
      radiusKm: targetRadius,
      errorMessage: null,
    );

    try {
      final stationsFuture = _repository.getGeoStations(
        targetLat,
        targetLon,
        radiusKm: targetRadius,
        includeDemo: state.allowDemo,
      );
      final observationsFuture = _repository.getGeoObservations(
        targetLat,
        targetLon,
        radiusKm: targetRadius,
        includeDemo: state.allowDemo,
      );
      final hotspotsFuture = _repository.getGeoHotspots(
        targetLat,
        targetLon,
        radiusKm: targetRadius,
        allowDemo: state.allowDemo,
      );
      final coverageFuture = _repository.getGeoCoverage(
        targetLat,
        targetLon,
        radiusKm: targetRadius,
        includeDemo: state.allowDemo,
      );

      final results = await Future.wait([
        stationsFuture,
        observationsFuture,
        hotspotsFuture,
        coverageFuture,
      ]);

      final stations = results[0] as List<GeoStationModel>;
      final observations = results[1] as List<GeoObservationModel>;
      final hotspots = results[2] as List<HotspotClusterModel>;
      final coverage = results[3] as GeoCoverageModel;

      state = state.copyWith(
        isLoading: false,
        stations: stations,
        observations: observations,
        hotspots: hotspots,
        coverage: coverage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve spatial air quality telemetry: $e',
      );
    }
  }

  void selectPollutant(String pollutant) {
    state = state.copyWith(selectedPollutant: pollutant);
  }

  void selectObservation(GeoObservationModel? obs) {
    state = state.copyWith(
      selectedObservation: obs,
      clearInterpolation: true,
    );
  }

  void selectStation(GeoStationModel? station) {
    state = state.copyWith(
      selectedStation: station,
      clearInterpolation: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedObservation: true,
      clearSelectedStation: true,
      clearInterpolation: true,
    );
  }

  Future<void> requestInterpolation(double targetLat, double targetLon) async {
    state = state.copyWith(
      isInterpolating: true,
      clearSelectedObservation: true,
      clearSelectedStation: true,
    );

    try {
      final interp = await _repository.getSpatialInterpolation(
        targetLat,
        targetLon,
        radiusKm: state.radiusKm,
        allowDemo: state.allowDemo,
      );
      state = state.copyWith(
        isInterpolating: false,
        activeInterpolation: interp,
      );
    } catch (e) {
      state = state.copyWith(
        isInterpolating: false,
        errorMessage: 'Failed to interpolate coordinate: $e',
      );
    }
  }

  void clearInterpolation() {
    state = state.copyWith(clearInterpolation: true);
  }

  void toggleHotspots() {
    state = state.copyWith(showHotspots: !state.showHotspots);
  }

  void toggleModelGrid() {
    state = state.copyWith(showModelGrid: !state.showModelGrid);
  }
}
