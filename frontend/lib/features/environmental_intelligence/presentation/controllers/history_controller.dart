import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/history_analytics_models.dart';
import 'environmental_controller.dart';

class HistoryState {
  final String selectedStationId;
  final String selectedStationName;
  final bool isPhysicalStation;
  final String selectedPeriod;
  final int selectedTab;

  final HistoricalSummaryModel? summary;
  final HistoricalTrendsModel? trends;
  final HistoricalCalendarModel? calendar;
  final HistoricalExtremesModel? extremes;
  final HistoricalCoverageModel? coverage;
  final HistoricalCompareModel? comparison;
  final HistoricalReportModel? report;
  final HistoricalExplanationModel? explanation;

  final String comparisonStationId;
  final bool isLoading;
  final bool isExplaining;
  final bool isGeneratingReport;
  final String? errorMessage;

  const HistoryState({
    this.selectedStationId = '',
    this.selectedStationName = 'Current Location',
    this.isPhysicalStation = false,
    this.selectedPeriod = '7d',
    this.selectedTab = 0,
    this.summary,
    this.trends,
    this.calendar,
    this.extremes,
    this.coverage,
    this.comparison,
    this.report,
    this.explanation,
    this.comparisonStationId = '',
    this.isLoading = false,
    this.isExplaining = false,
    this.isGeneratingReport = false,
    this.errorMessage,
  });

  HistoryState copyWith({
    String? selectedStationId,
    String? selectedStationName,
    bool? isPhysicalStation,
    String? selectedPeriod,
    int? selectedTab,
    HistoricalSummaryModel? summary,
    HistoricalTrendsModel? trends,
    HistoricalCalendarModel? calendar,
    HistoricalExtremesModel? extremes,
    HistoricalCoverageModel? coverage,
    HistoricalCompareModel? comparison,
    HistoricalReportModel? report,
    HistoricalExplanationModel? explanation,
    String? comparisonStationId,
    bool? isLoading,
    bool? isExplaining,
    bool? isGeneratingReport,
    String? errorMessage,
  }) {
    return HistoryState(
      selectedStationId: selectedStationId ?? this.selectedStationId,
      selectedStationName: selectedStationName ?? this.selectedStationName,
      isPhysicalStation: isPhysicalStation ?? this.isPhysicalStation,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedTab: selectedTab ?? this.selectedTab,
      summary: summary ?? this.summary,
      trends: trends ?? this.trends,
      calendar: calendar ?? this.calendar,
      extremes: extremes ?? this.extremes,
      coverage: coverage ?? this.coverage,
      comparison: comparison ?? this.comparison,
      report: report ?? this.report,
      explanation: explanation ?? this.explanation,
      comparisonStationId: comparisonStationId ?? this.comparisonStationId,
      isLoading: isLoading ?? this.isLoading,
      isExplaining: isExplaining ?? this.isExplaining,
      isGeneratingReport: isGeneratingReport ?? this.isGeneratingReport,
      errorMessage: errorMessage,
    );
  }
}

final historyControllerProvider =
    StateNotifierProvider<HistoryController, HistoryState>((ref) {
  final repo = ref.watch(environmentalRepositoryProvider);
  final controller = HistoryController(repo);

  void syncTo(UserLocationResult? location) {
    if (location == null) return;
    controller.useLocation(location);
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

class HistoryController extends StateNotifier<HistoryState> {
  final EnvironmentalRepository _repo;

  HistoryController(this._repo) : super(const HistoryState());

  static String stationIdFor(double lat, double lon) =>
      'METEO-GRID-${lat.toStringAsFixed(2)}-${lon.toStringAsFixed(2)}';

  static String stationNameFor(UserLocationResult location) {
    if (location.cityName != null && location.cityName!.isNotEmpty) {
      return '${location.cityName} Regional Model Grid';
    }
    return 'Regional Model Grid (${location.coordinateLabel})';
  }

  /// Points historical analytics at the user's current location.
  Future<void> useLocation(UserLocationResult location) async {
    final stationId = stationIdFor(location.latitude, location.longitude);
    if (stationId == state.selectedStationId && state.summary != null) return;

    state = state.copyWith(
      selectedStationId: stationId,
      selectedStationName: stationNameFor(location),
      isPhysicalStation: false,
      comparisonStationId: '',
    );

    await fetchHistoryData();
  }

  Future<void> initialize({
    String? stationId,
    String? stationName,
    bool? isPhysical,
    String? period,
  }) async {
    state = state.copyWith(
      selectedStationId: stationId ?? state.selectedStationId,
      selectedStationName: stationName ?? state.selectedStationName,
      isPhysicalStation: isPhysical ?? state.isPhysicalStation,
      selectedPeriod: period ?? state.selectedPeriod,
      isLoading: true,
      errorMessage: null,
    );

    await fetchHistoryData();
  }

  void setStation({
    required String stationId,
    required String stationName,
    required bool isPhysical,
  }) {
    state = state.copyWith(
      selectedStationId: stationId,
      selectedStationName: stationName,
      isPhysicalStation: isPhysical,
    );
    fetchHistoryData();
  }

  void setPeriod(String period) {
    if (state.selectedPeriod == period) return;
    state = state.copyWith(selectedPeriod: period);
    fetchHistoryData();
  }

  void setTab(int tabIndex) {
    state = state.copyWith(selectedTab: tabIndex);
  }

  void setComparisonStation(String stationB) {
    if (stationB.isEmpty || stationB == state.selectedStationId) return;
    state = state.copyWith(comparisonStationId: stationB);
    compareLocations(stationB);
  }

  Future<void> fetchHistoryData() async {
    if (state.selectedStationId.isEmpty) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final stationId = state.selectedStationId;
      final period = state.selectedPeriod;

      // Parallel fetch for optimal UX
      final summaryFuture = _repo.getHistorySummary(stationId, period: period);
      final trendsFuture = _repo.getHistoryTrends(stationId, period: period);
      final calendarFuture = _repo.getHistoryCalendar(stationId, period: period == '24h' ? '7d' : period);
      final extremesFuture = _repo.getHistoryExtremes(stationId, period: period);
      final coverageFuture = _repo.getHistoryCoverage(stationId, period: period);

      final results = await Future.wait([
        summaryFuture,
        trendsFuture,
        calendarFuture,
        extremesFuture,
        coverageFuture,
      ]);

      final summary = results[0] as HistoricalSummaryModel;
      final trends = results[1] as HistoricalTrendsModel;
      final calendar = results[2] as HistoricalCalendarModel;
      final extremes = results[3] as HistoricalExtremesModel;
      final coverage = results[4] as HistoricalCoverageModel;

      state = state.copyWith(
        summary: summary,
        trends: trends,
        calendar: calendar,
        extremes: extremes,
        coverage: coverage,
        isLoading: false,
      );

      // Auto-fetch explanation
      requestExplanation();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve historical environmental records: $e',
      );
    }
  }

  Future<void> compareLocations(String stationB) async {
    try {
      final comp = await _repo.compareHistoryLocations(
        state.selectedStationId,
        stationB,
        period: state.selectedPeriod,
      );
      state = state.copyWith(
        comparison: comp,
        comparisonStationId: stationB,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Comparison error: $e');
    }
  }

  Future<void> requestExplanation() async {
    if (state.summary == null) return;
    state = state.copyWith(isExplaining: true);

    try {
      final expl = await _repo.explainHistory(state.summary!, state.trends);
      state = state.copyWith(
        explanation: expl,
        isExplaining: false,
      );
    } catch (e) {
      state = state.copyWith(isExplaining: false);
    }
  }

  Future<HistoricalReportModel?> generateReport() async {
    state = state.copyWith(isGeneratingReport: true);
    try {
      final rpt = await _repo.getHistoryReport(
        state.selectedStationId,
        period: state.selectedPeriod,
      );
      state = state.copyWith(
        report: rpt,
        isGeneratingReport: false,
      );
      return rpt;
    } catch (e) {
      state = state.copyWith(
        isGeneratingReport: false,
        errorMessage: 'Failed to generate historical audit report: $e',
      );
      return null;
    }
  }
}
