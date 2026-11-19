import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/geo_models.dart';
import 'environmental_controller.dart';

class GeoState {
  final bool isLoading;
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final String locationLabel;
  final String selectedPollutant;
  final List<GeoStationModel> stations;
  final List<GeoObservationModel> observations;
  final List<HotspotClusterModel> hotspots;
  final GeoCoverageModel? coverage;
  final GeoHeatmapModel? heatmap;
  final GeoObservationModel? selectedObservation;
  final GeoStationModel? selectedStation;
  final SpatialInterpolationModel? activeInterpolation;
  final bool isInterpolating;
  final String? errorMessage;
  final bool showHotspots;
  final bool showHeatmap;
  final bool showModelGrid;
  final bool allowDemo;

  const GeoState({
    this.isLoading = false,
    this.centerLat = 18.5204,
    this.centerLon = 73.8567,
    this.radiusKm = 50.0,
    this.locationLabel = 'Current Location',
    this.selectedPollutant = 'AQI',
    this.stations = const [],
    this.observations = const [],
    this.hotspots = const [],
    this.coverage,
    this.heatmap,
    this.selectedObservation,
    this.selectedStation,
    this.activeInterpolation,
    this.isInterpolating = false,
    this.errorMessage,
    this.showHotspots = true,
    this.showHeatmap = true,
    this.showModelGrid = true,
    this.allowDemo = true,
  });

  GeoState copyWith({
    bool? isLoading,
    double? centerLat,
    double? centerLon,
    double? radiusKm,
    String? locationLabel,
    String? selectedPollutant,
    List<GeoStationModel>? stations,
    List<GeoObservationModel>? observations,
    List<HotspotClusterModel>? hotspots,
    GeoCoverageModel? coverage,
    GeoHeatmapModel? heatmap,
    GeoObservationModel? selectedObservation,
    GeoStationModel? selectedStation,
    SpatialInterpolationModel? activeInterpolation,
    bool? isInterpolating,
    String? errorMessage,
    bool? showHotspots,
    bool? showHeatmap,
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
      locationLabel: locationLabel ?? this.locationLabel,
      selectedPollutant: selectedPollutant ?? this.selectedPollutant,
      stations: stations ?? this.stations,
      observations: observations ?? this.observations,
      hotspots: hotspots ?? this.hotspots,
      coverage: coverage ?? this.coverage,
      heatmap: heatmap ?? this.heatmap,
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
      showHeatmap: showHeatmap ?? this.showHeatmap,
      showModelGrid: showModelGrid ?? this.showModelGrid,
      allowDemo: allowDemo ?? this.allowDemo,
    );
  }
}

final geoControllerProvider =
    StateNotifierProvider<GeoController, GeoState>((ref) {
  final repository = ref.watch(environmentalRepositoryProvider);
  final controller = GeoController(repository);

  void syncTo(UserLocationResult? location) {
    if (location == null) return;
    controller.centerOn(
      location.latitude,
      location.longitude,
      locationLabel: location.displayLocation,
    );
  }

  syncTo(ref.read(environmentalControllerProvider).userLocation);

  ref.listen<UserLocationResult?>(
    environmentalControllerProvider.select((s) => s.userLocation),
    (previous, next) {
      if (next == null) return;
      if (previous?.latitude == next.latitude &&
          previous?.longitude == next.longitude) {
        return;
      }
      syncTo(next);
    },
  );

  return controller;
});

class GeoController extends StateNotifier<GeoState> {
  final EnvironmentalRepository _repository;

  GeoController(this._repository) : super(const GeoState());

  /// Recenters geographic intelligence on the user's resolved location.
  Future<void> centerOn(
    double lat,
    double lon, {
    String? locationLabel,
  }) async {
    final sameCenter = (state.centerLat - lat).abs() < 0.000001 &&
        (state.centerLon - lon).abs() < 0.000001;

    if (sameCenter && state.observations.isNotEmpty) {
      if (locationLabel != null && locationLabel != state.locationLabel) {
        state = state.copyWith(locationLabel: locationLabel);
      }
      return;
    }

    if (locationLabel != null) {
      state = state.copyWith(locationLabel: locationLabel);
    }

    await loadGeographicData(lat: lat, lon: lon);
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
      final heatmapFuture = _repository.getGeoHeatmap(
        targetLat,
        targetLon,
        pollutant: state.selectedPollutant,
        radiusKm: targetRadius,
        allowDemo: state.allowDemo,
      );

      final results = await Future.wait([
        stationsFuture,
        observationsFuture,
        hotspotsFuture,
        coverageFuture,
        heatmapFuture,
      ]);

      final stations = results[0] as List<GeoStationModel>;
      final observations = results[1] as List<GeoObservationModel>;
      final hotspots = results[2] as List<HotspotClusterModel>;
      final coverage = results[3] as GeoCoverageModel;
      final heatmap = results[4] as GeoHeatmapModel?;

      state = state.copyWith(
        isLoading: false,
        stations: stations,
        observations: observations,
        hotspots: hotspots,
        coverage: coverage,
        heatmap: heatmap,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve spatial air quality telemetry: $e',
      );
    }
  }

  void selectPollutant(String pollutant) {
    if (state.selectedPollutant == pollutant) return;
    state = state.copyWith(selectedPollutant: pollutant);
    // The heatmap surface is pollutant-specific, so refresh it on change.
    _refreshHeatmap();
  }

  Future<void> _refreshHeatmap() async {
    final heatmap = await _repository.getGeoHeatmap(
      state.centerLat,
      state.centerLon,
      pollutant: state.selectedPollutant,
      radiusKm: state.radiusKm,
      allowDemo: state.allowDemo,
    );
    if (!mounted) return;
    state = state.copyWith(heatmap: heatmap);
  }

  void toggleHeatmap() {
    state = state.copyWith(showHeatmap: !state.showHeatmap);
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
