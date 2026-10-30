import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';

import 'features/auth/login_screen.dart';
import 'features/pm/site_detail/pm_site_detail_screen.dart';
import 'features/pm/dashboard/pm_dashboard_screen.dart';
import 'features/pm/profile/pm_profile_screen.dart';
import 'features/supervisor/home/supervisor_home_screen.dart';
import 'features/supervisor/profile/supervisor_profile_screen.dart';
import 'features/supervisor/roster/roster_screen.dart';
import 'features/supervisor/attendance/attendance_screen.dart';
import 'features/supervisor/material/material_usage_screen.dart';
import 'features/supervisor/incident/incident_screen.dart';

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
  required AuthRepository authRepository,
  String? initialLocation,
}) {
  final authRepo = authRepository;
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? '/login',
    refreshListenable: GoRouterRefreshStream(authRepo.watchCurrentUser()),
    redirect: (BuildContext context, GoRouterState state) {
      final user = authRepo.currentUser;
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || location == '/') {
        return user.role == UserRole.supervisor
            ? '/supervisor/home'
            : '/pm/dashboard';
      }

      if (user.role == UserRole.supervisor && location.startsWith('/pm')) {
        return '/supervisor/home';
      }

      if (user.role == UserRole.pm && location.startsWith('/supervisor')) {
        return '/pm/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _SupervisorNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/home',
                builder: (context, state) => const SupervisorHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/roster',
                builder: (context, state) => const RosterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/supervisor/profile',
                builder: (context, state) => const SupervisorProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/supervisor/material',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MaterialUsageScreen(),
      ),
      GoRoute(
        path: '/supervisor/attendance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/supervisor/incident',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const IncidentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _PmNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pm/dashboard',
                builder: (context, state) => const PmDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pm/profile',
                builder: (context, state) => const PmProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/pm/site/:siteId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final siteId = state.pathParameters['siteId'] ?? '';
          return PmSiteDetailScreen(siteId: siteId);
        },
      ),
    ],
  );
}

class _SupervisorNavigationShell extends StatelessWidget {
  const _SupervisorNavigationShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people), label: 'Roster'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _PmNavigationShell extends StatelessWidget {
  const _PmNavigationShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
