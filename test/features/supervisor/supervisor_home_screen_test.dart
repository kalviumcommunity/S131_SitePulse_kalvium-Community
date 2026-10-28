import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/features/supervisor/home/supervisor_home_screen.dart';

Widget buildScreen({
  FakeAuthRepository? authRepo,
  FakeSiteRepository? siteRepo,
  FakeAttendanceRepository? attendanceRepo,
  FakeMaterialRepository? materialRepo,
  FakeIncidentRepository? incidentRepo,
}) {
  const user = AppUser(
    uid: 'sup-1',
    name: 'Sarah Connor',
    role: UserRole.supervisor,
    siteId: 'site-1',
  );
  final actualAuth = authRepo ??
      FakeAuthRepository(
        initialUser: user,
        initialUsers: [user],
      );
  final actualSite = siteRepo ??
      FakeSiteRepository(
        initialSites: [
          Site(
            id: 'site-1',
            name: 'Downtown Heights',
            lastEntryAt: DateTime.now(),
          ),
        ],
      );

  final router = GoRouter(
    initialLocation: '/supervisor/home',
    routes: [
      GoRoute(
        path: '/supervisor/home',
        builder: (context, state) => const SupervisorHomeScreen(),
      ),
      GoRoute(
        path: '/supervisor/attendance',
        builder: (context, state) => const Scaffold(body: Text('Attendance Route')),
      ),
      GoRoute(
        path: '/supervisor/material',
        builder: (context, state) => const Scaffold(body: Text('Material Route')),
      ),
      GoRoute(
        path: '/supervisor/incident',
        builder: (context, state) => const Scaffold(body: Text('Incident Route')),
      ),
      GoRoute(
        path: '/supervisor/roster',
        builder: (context, state) => const Scaffold(body: Text('Roster Route')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('Login Route')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(actualAuth),
      siteRepositoryProvider.overrideWithValue(actualSite),
      if (attendanceRepo != null) attendanceRepositoryProvider.overrideWithValue(attendanceRepo),
      if (materialRepo != null) materialRepositoryProvider.overrideWithValue(materialRepo),
      if (incidentRepo != null) incidentRepositoryProvider.overrideWithValue(incidentRepo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  group('SupervisorHomeScreen Widget Tests', () {
    testWidgets('renders supervisor name, role, and site name in header', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Role: supervisor'), findsOneWidget);
      expect(find.byKey(const Key('site_name_header')), findsOneWidget);
      expect(find.text('Downtown Heights'), findsOneWidget);
    });

    testWidgets('renders all 4 action cards/buttons', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('action_attendance')), findsOneWidget);
      expect(find.byKey(const Key('action_material')), findsOneWidget);
      expect(find.byKey(const Key('action_incident')), findsOneWidget);
      expect(find.byKey(const Key('action_roster')), findsOneWidget);
    });

    testWidgets('tapping action cards navigates to corresponding routes', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Test Attendance Navigation
      await tester.tap(find.byKey(const Key('action_attendance')));
      await tester.pumpAndSettle();
      expect(find.text('Attendance Route'), findsOneWidget);
    });

    testWidgets('tapping material card navigates to material route', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('action_material')));
      await tester.pumpAndSettle();
      expect(find.text('Material Route'), findsOneWidget);
    });

    testWidgets('tapping incident card navigates to incident route', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('action_incident')));
      await tester.pumpAndSettle();
      expect(find.text('Incident Route'), findsOneWidget);
    });

    testWidgets('tapping roster card navigates to roster route', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('action_roster')));
      await tester.pumpAndSettle();
      expect(find.text('Roster Route'), findsOneWidget);
    });

    testWidgets('renders recent activity feed items from repositories', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Recent Activity Feed'), findsOneWidget);
      expect(find.text('Latest 10 items'), findsOneWidget);
    });

    testWidgets('shows empty view when no activity exists', (tester) async {
      final emptyIncidentRepo = FakeIncidentRepository(initialIncidents: []);
      final emptyMaterialRepo = FakeMaterialRepository(initialMaterials: []);
      final emptyAttendanceRepo = FakeAttendanceRepository(initialAttendance: []);

      await tester.pumpWidget(
        buildScreen(
          incidentRepo: emptyIncidentRepo,
          materialRepo: emptyMaterialRepo,
          attendanceRepo: emptyAttendanceRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('No recent activity recorded for this site yet.'),
        findsOneWidget,
      );
    });
  });
}
