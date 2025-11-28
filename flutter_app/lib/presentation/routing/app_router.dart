import 'package:go_router/go_router.dart';
import '../common/screens/splash_screen.dart';
import '../auth/screens/login_screen.dart';
import '../admin/screens/admin_dashboard_screen.dart';
import '../staff/screens/staff_dashboard_screen.dart';
import '../student/screens/student_dashboard_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';

final appRouter = GoRouter(
  initialLocation: RoutePaths.root,
  errorPageBuilder: (context, state) {
    return const NoTransitionPage(
      child: Scaffold(
        body: Center(
          child: Text('Page not found'),
        ),
      ),
    );
  },
  routes: [
    GoRoute(
      path: RoutePaths.root,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RoutePaths.adminDashboard,
      name: RouteNames.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: RoutePaths.staffDashboard,
      name: RouteNames.staffDashboard,
      builder: (context, state) => const StaffDashboardScreen(),
    ),
    GoRoute(
      path: RoutePaths.studentDashboard,
      name: RouteNames.studentDashboard,
      builder: (context, state) => const StudentDashboardScreen(),
    ),
  ],
);
