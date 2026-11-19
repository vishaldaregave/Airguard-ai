import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/environmental_intelligence/presentation/screens/dashboard_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/alert_inbox_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/alert_preferences_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/geo_map_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/exposure_simulator_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/historical_intelligence_screen.dart';
import '../theme/cloudy_background.dart';

/// Pushed routes replace the dashboard instead of stacking on it, so they need
/// the sky backdrop applied explicitly to avoid a flat background.
Widget _withBackdrop(Widget child) => CloudyBackground(child: child);

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => _withBackdrop(const AlertInboxScreen()),
    ),
    GoRoute(
      path: '/alerts/preferences',
      builder: (context, state) =>
          _withBackdrop(const AlertPreferencesScreen()),
    ),
    GoRoute(
      path: '/geo',
      builder: (context, state) => _withBackdrop(const GeoMapScreen()),
    ),
    GoRoute(
      path: '/exposure',
      builder: (context, state) =>
          _withBackdrop(const ExposureSimulatorScreen()),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) =>
          _withBackdrop(const HistoricalIntelligenceScreen()),
    ),
  ],
);
