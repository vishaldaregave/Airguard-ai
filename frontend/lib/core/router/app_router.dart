import 'package:go_router/go_router.dart';
import '../../features/environmental_intelligence/presentation/screens/dashboard_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
