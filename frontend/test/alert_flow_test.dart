import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/alert_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/alert_inbox_screen.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/alert_preferences_screen.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/alert_detail_sheet.dart';

class MockAlertRepository extends EnvironmentalRepository {
  MockAlertRepository() : super(ApiClient());

  final List<AlertItem> _mockAlerts = [
    AlertItem(
      alertId: 'alert-1',
      userId: 'test_user',
      alertType: AlertType.aqiThreshold,
      severity: AlertSeverity.danger,
      stationCode: 'DELHI_ANAND_VIHAR',
      stationName: 'Anand Vihar, Delhi',
      pollutant: 'PM2.5',
      observedValue: 310.0,
      thresholdValue: 200.0,
      unit: 'AQI',
      sourceProvenance: 'LIVE',
      observationTimestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      triggerReason: 'CPCB AQI reached 310 (Very Poor), exceeding threshold of 200.',
      recommendedPrecaution: 'Avoid prolonged outdoor exertion. Wear certified N95 respirator.',
      isForecast: false,
      forecastHorizonHours: null,
      isRead: false,
      isResolved: false,
      deliveryStatus: 'DELIVERED',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AlertItem(
      alertId: 'alert-2',
      userId: 'test_user',
      alertType: AlertType.forecastWarning,
      severity: AlertSeverity.warning,
      stationCode: 'DELHI_LODHI_ROAD',
      stationName: 'Lodhi Road, Delhi',
      pollutant: 'PM2.5',
      observedValue: 220.0,
      thresholdValue: 200.0,
      unit: 'AQI (Forecast)',
      sourceProvenance: 'FORECAST',
      observationTimestamp: DateTime.now().add(const Duration(hours: 3)),
      triggerReason: 'Predicted +3h CPCB AQI (220) is forecast to exceed your threshold of 200.',
      recommendedPrecaution: 'Plan outdoor schedules ahead. Elevated particulates forecast in 3 hours.',
      isForecast: true,
      forecastHorizonHours: 3,
      isRead: true,
      isResolved: false,
      deliveryStatus: 'DELIVERED',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  @override
  Future<AlertListResponse> getAlerts({
    bool unreadOnly = false,
    String? severity,
    int limit = 50,
    int offset = 0,
  }) async {
    var filtered = _mockAlerts;
    if (unreadOnly) {
      filtered = filtered.where((a) => !a.isRead).toList();
    }
    if (severity != null) {
      filtered = filtered.where((a) => a.severity.displayName == severity).toList();
    }
    return AlertListResponse(
      alerts: filtered,
      total: filtered.length,
      unreadCount: _mockAlerts.where((a) => !a.isRead).length,
    );
  }

  @override
  Future<UserAlertPreference> getUserPreferences() async {
    return UserAlertPreference(
      userId: 'test_user',
      notificationsEnabled: true,
      aqiThreshold: 200,
      pm25Threshold: 60.0,
      pm10Threshold: 100.0,
      suddenDeteriorationEnabled: true,
      forecastAlertsEnabled: true,
      recoveryAlertsEnabled: true,
      quietHoursEnabled: true,
      quietHoursStart: 22,
      quietHoursEnd: 7,
      preferredStationCode: 'DELHI_ANAND_VIHAR',
      preferredStationName: 'Anand Vihar, Delhi',
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<UserAlertPreference> updateUserPreferences(UserAlertPreference prefs) async {
    return prefs;
  }

  @override
  Future<bool> markAlertRead(String alertId) async {
    return true;
  }
}

void main() {
  group('Alert Domain Models', () {
    test('AlertItem and AlertListResponse parse correctly from JSON', () {
      final json = {
        'alerts': [
          {
            'alert_id': 'alert-uuid-1234',
            'user_id': 'user_01',
            'alert_type': 'AQI_THRESHOLD',
            'severity': 'DANGER',
            'station_code': 'DELHI_ANAND_VIHAR',
            'station_name': 'Anand Vihar, Delhi',
            'pollutant': 'PM2.5',
            'observed_value': 315.0,
            'threshold_value': 200.0,
            'unit': 'AQI',
            'source_provenance': 'LIVE',
            'observation_timestamp': '2026-11-16T10:00:00Z',
            'trigger_reason': 'CPCB AQI reached 315 (Very Poor), exceeding threshold of 200.',
            'recommended_precaution': 'Remain indoors and wear N95 mask.',
            'is_forecast': false,
            'forecast_horizon_hours': null,
            'is_read': false,
            'is_resolved': false,
            'delivery_status': 'DELIVERED',
            'created_at': '2026-11-16T10:00:02Z',
          },
        ],
        'total': 1,
        'unread_count': 1,
      };

      final resp = AlertListResponse.fromJson(json);
      expect(resp.total, 1);
      expect(resp.unreadCount, 1);
      expect(resp.alerts.length, 1);

      final item = resp.alerts.first;
      expect(item.alertId, 'alert-uuid-1234');
      expect(item.alertType, AlertType.aqiThreshold);
      expect(item.severity, AlertSeverity.danger);
      expect(item.observedValue, 315.0);
      expect(item.thresholdValue, 200.0);
      expect(item.isForecast, false);
      expect(item.isRead, false);
    });

    test('UserAlertPreference parses, serializes, and copies correctly', () {
      final json = {
        'user_id': 'user_01',
        'notifications_enabled': true,
        'aqi_threshold': 180,
        'pm25_threshold': 55.0,
        'pm10_threshold': 95.0,
        'sudden_deterioration_enabled': true,
        'forecast_alerts_enabled': false,
        'recovery_alerts_enabled': true,
        'quiet_hours_enabled': true,
        'quiet_hours_start': 23,
        'quiet_hours_end': 6,
        'preferred_station_code': 'DELHI_ANAND_VIHAR',
        'preferred_station_name': 'Anand Vihar, Delhi',
        'updated_at': '2026-11-16T09:00:00Z',
      };

      final pref = UserAlertPreference.fromJson(json);
      expect(pref.userId, 'user_01');
      expect(pref.aqiThreshold, 180);
      expect(pref.pm25Threshold, 55.0);
      expect(pref.forecastAlertsEnabled, false);
      expect(pref.quietHoursEnabled, true);

      final map = pref.toJson();
      expect(map['aqi_threshold'], 180);
      expect(map['quiet_hours_enabled'], true);

      final updated = pref.copyWith(aqiThreshold: 220, notificationsEnabled: false);
      expect(updated.aqiThreshold, 220);
      expect(updated.notificationsEnabled, false);
      expect(updated.quietHoursEnabled, true);
    });
  });

  group('Alert Widgets & Screens', () {
    testWidgets('AlertInboxScreen renders alert list, filters, and severity badges', (tester) async {
      final mockRepo = MockAlertRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AlertInboxScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Environmental Alerts'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('UNREAD'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('DANGER'), findsWidgets);
      expect(find.text('WARNING'), findsWidgets);

      expect(find.text('AQI Threshold'), findsOneWidget);
      expect(find.text('Forecast Warning'), findsOneWidget);
      expect(find.text('Anand Vihar, Delhi'), findsOneWidget);
      expect(find.text('Lodhi Road, Delhi'), findsOneWidget);
      expect(find.text('OBSERVED'), findsOneWidget);
      expect(find.text('FORECAST (+3h)'), findsOneWidget);
    });

    testWidgets('AlertPreferencesScreen renders threshold controls and quiet hours', (tester) async {
      final mockRepo = MockAlertRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AlertPreferencesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('Enable Environmental Alerts'), findsOneWidget);
      expect(find.text('CPCB AQI Alert Threshold'), findsOneWidget);
      expect(find.text('PM2.5 Notification Limit'), findsOneWidget);
      expect(find.text('PM10 Notification Limit'), findsOneWidget);
      expect(find.text('Sudden Deterioration Warnings'), findsOneWidget);
      expect(find.text('Forecast-Based Warnings'), findsOneWidget);
      expect(find.text('Enable Quiet Hours'), findsOneWidget);
      expect(find.text('Save Preferences'), findsOneWidget);
    });

    testWidgets('AlertDetailSheet displays evidence-based precautions and forecast labels', (tester) async {
      final alert = AlertItem(
        alertId: 'alert-test-sheet',
        userId: 'test_user',
        alertType: AlertType.aqiThreshold,
        severity: AlertSeverity.danger,
        stationCode: 'DELHI_ANAND_VIHAR',
        stationName: 'Anand Vihar, Delhi',
        pollutant: 'PM2.5',
        observedValue: 320.0,
        thresholdValue: 200.0,
        unit: 'AQI',
        sourceProvenance: 'LIVE',
        observationTimestamp: DateTime.now(),
        triggerReason: 'CPCB AQI reached 320 (Very Poor).',
        recommendedPrecaution: 'Wear certified N95 respirator. Keep air purifiers active.',
        isForecast: false,
        forecastHorizonHours: null,
        isRead: false,
        isResolved: false,
        deliveryStatus: 'DELIVERED',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertDetailSheet(alert: alert),
          ),
        ),
      );

      expect(find.text('DANGER'), findsWidgets);
      expect(find.text('OBSERVED (LIVE)'), findsOneWidget);
      expect(find.text('AQI Threshold'), findsOneWidget);
      expect(find.text('Anand Vihar, Delhi'), findsOneWidget);
      expect(find.text('EVIDENCE-BASED PRECAUTION'), findsOneWidget);
      expect(find.text('Wear certified N95 respirator. Keep air purifiers active.'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });
}
