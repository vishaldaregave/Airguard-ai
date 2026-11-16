import 'package:go_router/go_router.dart';
import '../../features/environmental_intelligence/presentation/screens/dashboard_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/alert_inbox_screen.dart';
import '../../features/environmental_intelligence/presentation/screens/alert_preferences_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertInboxScreen(),
    ),
    GoRoute(
      path: '/alerts/preferences',
      builder: (context, state) => const AlertPreferencesScreen(),
    ),
  ],
);
