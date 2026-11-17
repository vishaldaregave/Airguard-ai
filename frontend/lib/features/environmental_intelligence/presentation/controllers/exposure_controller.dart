import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/exposure_models.dart';

class ExposureState {
  final List<ActivityProfileModel> activityProfiles;
  final ActivityProfileModel? selectedActivity;
  final int durationMinutes;
  final bool isForecastMode;
  final int forecastOffsetHours;
  final bool isComparisonMode;
  final ActivityProfileModel? scenarioBActivity;
  final int scenarioBDurationMinutes;
  final ExposureSimulationModel? currentSimulation;
  final ExposureComparisonModel? currentComparison;
  final ExposureExplanationModel? explanation;
  final bool isLoading;
  final bool isExplaining;
  final String? errorMessage;
  final double? latitude;
  final double? longitude;
  final String? stationId;
  final String locationName;

  const ExposureState({
    this.activityProfiles = const [],
    this.selectedActivity,
    this.durationMinutes = 60,
    this.isForecastMode = false,
    this.forecastOffsetHours = 1,
    this.isComparisonMode = false,
    this.scenarioBActivity,
    this.scenarioBDurationMinutes = 30,
    this.currentSimulation,
    this.currentComparison,
    this.explanation,
    this.isLoading = false,
    this.isExplaining = false,
    this.errorMessage,
    this.latitude,
    this.longitude,
    this.stationId,
    this.locationName = 'Current Location',
  });

  ExposureState copyWith({
    List<ActivityProfileModel>? activityProfiles,
    ActivityProfileModel? selectedActivity,
    int? durationMinutes,
    bool? isForecastMode,
    int? forecastOffsetHours,
    bool? isComparisonMode,
    ActivityProfileModel? scenarioBActivity,
    int? scenarioBDurationMinutes,
    ExposureSimulationModel? currentSimulation,
    ExposureComparisonModel? currentComparison,
    ExposureExplanationModel? explanation,
    bool? isLoading,
    bool? isExplaining,
    String? errorMessage,
    double? latitude,
    double? longitude,
    String? stationId,
    String? locationName,
  }) {
    return ExposureState(
      activityProfiles: activityProfiles ?? this.activityProfiles,
      selectedActivity: selectedActivity ?? this.selectedActivity,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isForecastMode: isForecastMode ?? this.isForecastMode,
      forecastOffsetHours: forecastOffsetHours ?? this.forecastOffsetHours,
      isComparisonMode: isComparisonMode ?? this.isComparisonMode,
      scenarioBActivity: scenarioBActivity ?? this.scenarioBActivity,
      scenarioBDurationMinutes: scenarioBDurationMinutes ?? this.scenarioBDurationMinutes,
      currentSimulation: currentSimulation ?? this.currentSimulation,
      currentComparison: currentComparison ?? this.currentComparison,
      explanation: explanation ?? this.explanation,
      isLoading: isLoading ?? this.isLoading,
      isExplaining: isExplaining ?? this.isExplaining,
      errorMessage: errorMessage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stationId: stationId ?? this.stationId,
      locationName: locationName ?? this.locationName,
    );
  }
}

final exposureControllerProvider =
    StateNotifierProvider<ExposureController, ExposureState>((ref) {
  final repo = ref.watch(environmentalRepositoryProvider);
  return ExposureController(repo);
});

class ExposureController extends StateNotifier<ExposureState> {
  final EnvironmentalRepository _repo;

  ExposureController(this._repo) : super(const ExposureState()) {
    initialize();
  }

  Future<void> initialize({
    double? lat,
    double? lon,
    String? stationId,
    String? stationName,
  }) async {
    state = state.copyWith(
      isLoading: true,
      latitude: lat ?? 28.6139,
      longitude: lon ?? 77.2090,
      stationId: stationId,
      locationName: stationName ?? 'Delhi Central',
    );

    try {
      final profiles = await _repo.getActivityProfiles();
      final defaultAct = profiles.firstWhere(
        (p) => p.activityType == ActivityTypeEnum.walking,
        orElse: () => profiles.isNotEmpty ? profiles.first : const ActivityProfileModel(
          activityType: ActivityTypeEnum.walking,
          displayName: 'Walking',
          inhalationRateM3H: 1.20,
          metEquivalent: 3.0,
          description: 'Standard walking',
          reference: 'EPA EFH',
        ),
      );
      final defaultScenB = profiles.firstWhere(
        (p) => p.activityType == ActivityTypeEnum.running,
        orElse: () => defaultAct,
      );

      state = state.copyWith(
        activityProfiles: profiles,
        selectedActivity: defaultAct,
        scenarioBActivity: defaultScenB,
        isLoading: false,
      );

      // Run initial simulation
      await runSimulation();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load activity profiles: $e',
      );
    }
  }

  void selectActivity(ActivityProfileModel profile) {
    state = state.copyWith(selectedActivity: profile);
  }

  void setDuration(int minutes) {
    final clamped = minutes.clamp(15, 480);
    state = state.copyWith(durationMinutes: clamped);
  }

  void toggleForecastMode(bool enabled) {
    state = state.copyWith(isForecastMode: enabled);
  }

  void setForecastOffsetHours(int hours) {
    state = state.copyWith(forecastOffsetHours: hours.clamp(0, 24));
  }

  void toggleComparisonMode(bool enabled) {
    state = state.copyWith(isComparisonMode: enabled);
    if (enabled && state.currentComparison == null) {
      runComparison();
    }
  }

  void selectScenarioBActivity(ActivityProfileModel profile) {
    state = state.copyWith(scenarioBActivity: profile);
  }

  void setScenarioBDuration(int minutes) {
    final clamped = minutes.clamp(15, 480);
    state = state.copyWith(scenarioBDurationMinutes: clamped);
  }

  Future<void> runSimulation() async {
    final act = state.selectedActivity;
    if (act == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final req = {
        'activity_type': act.activityType.keyName,
        'duration_minutes': state.durationMinutes,
        'latitude': state.latitude,
        'longitude': state.longitude,
        'station_id': state.stationId,
        'use_interpolation': true,
        'use_forecast': state.isForecastMode,
        'forecast_start_offset_hours': state.forecastOffsetHours,
        'allow_demo': false,
      };

      final sim = await _repo.simulateExposure(req);
      state = state.copyWith(
        currentSimulation: sim,
        isLoading: false,
      );

      // Automatically produce physical explanation
      await requestExplanation(sim);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Simulation failed: $e',
      );
    }
  }

  Future<void> runComparison() async {
    final actA = state.selectedActivity;
    final actB = state.scenarioBActivity ?? actA;
    if (actA == null || actB == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final reqA = {
        'activity_type': actA.activityType.keyName,
        'duration_minutes': state.durationMinutes,
        'latitude': state.latitude,
        'longitude': state.longitude,
        'station_id': state.stationId,
        'use_forecast': state.isForecastMode,
      };

      final reqB = {
        'activity_type': actB.activityType.keyName,
        'duration_minutes': state.scenarioBDurationMinutes,
        'latitude': state.latitude,
        'longitude': state.longitude,
        'station_id': state.stationId,
        'use_forecast': state.isForecastMode,
      };

      final compareReq = {
        'scenario_a': reqA,
        'scenario_b': reqB,
        'label_a': '${actA.displayName} (${state.durationMinutes}m)',
        'label_b': '${actB.displayName} (${state.scenarioBDurationMinutes}m)',
      };

      final comp = await _repo.compareExposure(compareReq);
      state = state.copyWith(
        currentComparison: comp,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Comparison failed: $e',
      );
    }
  }

  Future<void> requestExplanation([ExposureSimulationModel? simulation]) async {
    final sim = simulation ?? state.currentSimulation;
    if (sim == null) return;

    state = state.copyWith(isExplaining: true);

    try {
      final expl = await _repo.explainExposure(sim);
      state = state.copyWith(
        explanation: expl,
        isExplaining: false,
      );
    } catch (e) {
      state = state.copyWith(isExplaining: false);
    }
  }
}
