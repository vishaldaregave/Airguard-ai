import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/environmental_repository.dart';
import '../../domain/models/alert_model.dart';

class AlertState {
  final bool isLoading;
  final bool isUpdatingPrefs;
  final List<AlertItem> alerts;
  final int unreadCount;
  final int total;
  final UserAlertPreference? preferences;
  final String? severityFilter;
  final bool unreadOnly;
  final String? errorMessage;

  const AlertState({
    this.isLoading = false,
    this.isUpdatingPrefs = false,
    this.alerts = const [],
    this.unreadCount = 0,
    this.total = 0,
    this.preferences,
    this.severityFilter,
    this.unreadOnly = false,
    this.errorMessage,
  });

  AlertState copyWith({
    bool? isLoading,
    bool? isUpdatingPrefs,
    List<AlertItem>? alerts,
    int? unreadCount,
    int? total,
    UserAlertPreference? preferences,
    String? severityFilter,
    bool? unreadOnly,
    String? errorMessage,
  }) {
    return AlertState(
      isLoading: isLoading ?? this.isLoading,
      isUpdatingPrefs: isUpdatingPrefs ?? this.isUpdatingPrefs,
      alerts: alerts ?? this.alerts,
      unreadCount: unreadCount ?? this.unreadCount,
      total: total ?? this.total,
      preferences: preferences ?? this.preferences,
      severityFilter: severityFilter ?? this.severityFilter,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      errorMessage: errorMessage,
    );
  }
}

class AlertNotifier extends StateNotifier<AlertState> {
  final EnvironmentalRepository _repository;

  AlertNotifier(this._repository) : super(const AlertState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchAlerts(),
      fetchPreferences(),
    ]);
  }

  Future<void> fetchAlerts({bool? unreadOnly, String? severity}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final unread = unreadOnly ?? state.unreadOnly;
      final sev = severity ?? state.severityFilter;
      final response = await _repository.getAlerts(
        unreadOnly: unread,
        severity: sev,
      );
      state = state.copyWith(
        isLoading: false,
        alerts: response.alerts,
        total: response.total,
        unreadCount: response.unreadCount,
        unreadOnly: unread,
        severityFilter: sev,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to retrieve environmental alerts: ${e.toString()}',
      );
    }
  }

  Future<void> fetchPreferences() async {
    try {
      final prefs = await _repository.getUserPreferences();
      state = state.copyWith(preferences: prefs);
    } catch (e) {
      // Retain existing or fallback
    }
  }

  Future<bool> updatePreferences(UserAlertPreference newPrefs) async {
    state = state.copyWith(isUpdatingPrefs: true, errorMessage: null);
    try {
      final updated = await _repository.updateUserPreferences(newPrefs);
      state = state.copyWith(isUpdatingPrefs: false, preferences: updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdatingPrefs: false,
        errorMessage: 'Failed to update preferences: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> markAlertAsRead(String alertId) async {
    try {
      final success = await _repository.markAlertRead(alertId);
      if (success) {
        final updatedList = state.alerts.map((a) {
          if (a.alertId == alertId) {
            return a.copyWith(isRead: true);
          }
          return a;
        }).toList();
        final newUnread = (state.unreadCount - 1).clamp(0, 9999);
        state = state.copyWith(alerts: updatedList, unreadCount: newUnread);
      }
    } catch (e) {
      // Silently handle
    }
  }

  Future<void> markAllAsRead() async {
    final unreadList = state.alerts.where((a) => !a.isRead).toList();
    for (final a in unreadList) {
      await _repository.markAlertRead(a.alertId);
    }
    final updatedList = state.alerts.map((a) => a.copyWith(isRead: true)).toList();
    state = state.copyWith(alerts: updatedList, unreadCount: 0);
  }

  void setFilter({bool? unreadOnly, String? severity}) {
    fetchAlerts(unreadOnly: unreadOnly, severity: severity);
  }
}

final alertControllerProvider =
    StateNotifierProvider<AlertNotifier, AlertState>((ref) {
  final repo = ref.watch(environmentalRepositoryProvider);
  return AlertNotifier(repo);
});
