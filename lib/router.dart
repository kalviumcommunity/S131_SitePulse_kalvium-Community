import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/fakes/fake_auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/pm/dashboard/pm_dashboard_screen.dart';
import 'features/supervisor/home/supervisor_home_screen.dart';
import 'features/supervisor/roster/roster_screen.dart';
import 'features/supervisor/attendance/attendance_screen.dart';

/// Global repository instance shared between router and auth features
AuthRepository _globalAuthRepository = FakeAuthRepository(
  initialUser: null, // Default to signed-out state on boot
);

AuthRepository get currentAuthRepository => _globalAuthRepository;
set currentAuthRepository(AuthRepository repo) => _globalAuthRepository = repo;

/// Converts a Stream into a Listenable for GoRouter refreshListenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter buildRouter({
  required bool firebaseReady,
  AuthRepository? authRepository,
  String? initialLocation,
}) {
  final authRepo = authRepository ?? currentAuthRepository;

  return GoRouter(
    initialLocation: initialLocation ?? '/login',
    refreshListenable: GoRouterRefreshStream(authRepo.watchCurrentUser()),
    redirect: (BuildContext context, GoRouterState state) {
      final user = authRepo.currentUser;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';

      // 1. Signed out -> must go to /login
      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Signed in trying to access /login or / -> redirect to role home
      if (isLoggingIn || location == '/') {
        return user.role == UserRole.supervisor
            ? '/supervisor/home'
            : '/pm/dashboard';
      }

      // 3. Supervisor must be redirected away from any /pm route
      if (user.role == UserRole.supervisor && location.startsWith('/pm')) {
        return '/supervisor/home';
      }

      // 4. PM must be redirected away from any /supervisor route
      if (user.role == UserRole.pm && location.startsWith('/supervisor')) {
        return '/pm/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/supervisor/home',
        builder: (context, state) => const SupervisorHomeScreen(),
      ),
      GoRoute(
        path: '/supervisor/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/supervisor/roster',
        builder: (context, state) => const RosterScreen(),
      ),
      GoRoute(
        path: '/pm/dashboard',
        builder: (context, state) => const PmDashboardScreen(),
      ),
    ],
  );
}