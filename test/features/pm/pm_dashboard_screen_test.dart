import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/features/pm/dashboard/pm_dashboard_screen.dart';

class _TrackingMaterialRepository extends FakeMaterialRepository {
  final List<String?> siteIds = [];

  @override
  Stream<List<sp.Material>> watchMaterials({String? siteId}) {
    siteIds.add(siteId);
    return super.watchMaterials(siteId: siteId);
  }
}

class _TrackingIncidentRepository extends FakeIncidentRepository {
  _TrackingIncidentRepository({super.initialIncidents});

  final List<String?> siteIds = [];

  @override
  Stream<List<Incident>> watchIncidents({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  }) {
    siteIds.add(siteId);
    return super.watchIncidents(
      siteId: siteId,
      startDate: startDate,
      endDate: endDate,
      severity: severity,
    );
  }
}

class _TrackingAttendanceRepository extends FakeAttendanceRepository {
  _TrackingAttendanceRepository({super.initialAttendance});

  final List<String?> siteIds = [];

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    siteIds.add(siteId);
    return super.watchAttendance(
      siteId: siteId,
      date: date,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

class _NeverEmittingMaterialRepository extends FakeMaterialRepository {
  @override
  Stream<List<sp.Material>> watchMaterials({String? siteId}) {
    return const Stream<List<sp.Material>>.empty();
  }
}

Widget buildDashboardApp({
  FakeAuthRepository? authRepo,
  FakeSiteRepository? siteRepo,
  FakeMaterialRepository? materialRepo,
  FakeIncidentRepository? incidentRepo,
  FakeAttendanceRepository? attendanceRepo,
}) {
  const pmUser = AppUser(
    uid: 'pm-1',
    name: 'Priya Sharma',
    role: UserRole.pm,
    siteId: null,
  );
  final actualAuth =
      authRepo ??
      FakeAuthRepository(initialUser: pmUser, initialUsers: [pmUser]);
  final actualSite = siteRepo ?? FakeSiteRepository();
  final actualMaterial = materialRepo ?? FakeMaterialRepository();
  final actualIncident = incidentRepo ?? FakeIncidentRepository();
  final actualAttendance = attendanceRepo ?? FakeAttendanceRepository();

  final router = GoRouter(
    initialLocation: '/pm/dashboard',
    routes: [
      GoRoute(
        path: '/pm/dashboard',
        builder: (context, state) => const PmDashboardScreen(),
      ),
      GoRoute(
        path: '/pm/site/:siteId',
        builder: (context, state) => Scaffold(
          body: Text('Site Detail: ${state.pathParameters['siteId']}'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('Login Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(actualAuth),
      siteRepositoryProvider.overrideWithValue(actualSite),
      materialRepositoryProvider.overrideWithValue(actualMaterial),
      incidentRepositoryProvider.overrideWithValue(actualIncident),
      attendanceRepositoryProvider.overrideWithValue(actualAttendance),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('PmDashboardScreen Widget Tests', () {
    testWidgets('renders PM header info and logout button', (tester) async {
      await tester.pumpWidget(buildDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PM Dashboard'), findsOneWidget);
      expect(find.text('Name: Priya Sharma'), findsOneWidget);
      expect(find.text('Role: pm'), findsOneWidget);
      expect(find.byKey(const Key('logout_button')), findsOneWidget);
      expect(find.byKey(const Key('logout_button_large')), findsOneWidget);
    });

    testWidgets('renders all 3 summary metric cards', (tester) async {
      await tester.pumpWidget(buildDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('metric_crew_attendance')), findsOneWidget);
      expect(find.byKey(const Key('metric_low_stock')), findsOneWidget);
      expect(find.byKey(const Key('metric_high_incidents')), findsOneWidget);
    });

    testWidgets('renders site filter dropdown and date range button', (
      tester,
    ) async {
      await tester.pumpWidget(buildDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('pm_site_filter')), findsOneWidget);
      expect(find.byKey(const Key('pm_date_filter')), findsOneWidget);
    });

    testWidgets('renders site cards for seeded sites', (tester) async {
      await tester.pumpWidget(buildDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('site_card_site-1')), findsOneWidget);
      expect(find.byKey(const Key('site_card_site-2')), findsOneWidget);
      expect(find.byKey(const Key('site_card_site-3')), findsOneWidget);
      expect(find.text('Downtown Heights'), findsOneWidget);
    });

    testWidgets('tapping a site card navigates to /pm/site/:siteId', (
      tester,
    ) async {
      await tester.pumpWidget(buildDashboardApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('site_card_site-1')));
      await tester.pumpAndSettle();

      expect(find.text('Site Detail: site-1'), findsOneWidget);
    });

    testWidgets('shows empty view when no sites match or sites list is empty', (
      tester,
    ) async {
      final emptySiteRepo = FakeSiteRepository(initialSites: []);
      await tester.pumpWidget(buildDashboardApp(siteRepo: emptySiteRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No sites match the selected filter.'), findsOneWidget);
    });

    testWidgets(
      'calculates low stock count and high incidents metric correctly',
      (tester) async {
        final matRepo = FakeMaterialRepository(
          initialMaterials: [
            const sp.Material(
              id: 'm1',
              name: 'Cement',
              unit: 'bags',
              openingStock: 100,
              currentStock: 10,
              lowStockThreshold: 20, // Low stock!
            ),
            const sp.Material(
              id: 'm2',
              name: 'Gravel',
              unit: 'tons',
              openingStock: 100,
              currentStock: 80,
              lowStockThreshold: 20, // Normal
            ),
          ],
        );
        final incRepo = FakeIncidentRepository(
          initialIncidents: [
            Incident(
              id: 'i-1',
              severity: Severity.critical, // High/Critical!
              description: 'Trench collapse warning',
              occurredAt: DateTime.now(),
            ),
            Incident(
              id: 'i-2',
              severity: Severity.minor, // Minor
              description: 'Paper cut in trailer',
              occurredAt: DateTime.now(),
            ),
          ],
        );

        await tester.pumpWidget(
          buildDashboardApp(materialRepo: matRepo, incidentRepo: incRepo),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('1'),
          findsNWidgets(2),
        ); // 1 low stock material & 1 critical incident
      },
    );

    testWidgets(
      'site filter scopes materials, incidents, and attendance data',
      (tester) async {
        final materialRepo = _TrackingMaterialRepository();
        final incidentRepo = _TrackingIncidentRepository(initialIncidents: []);
        final attendanceRepo = _TrackingAttendanceRepository(
          initialAttendance: [],
        );

        await tester.pumpWidget(
          buildDashboardApp(
            materialRepo: materialRepo,
            incidentRepo: incidentRepo,
            attendanceRepo: attendanceRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('pm_site_filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Downtown Heights').last);
        await tester.pumpAndSettle();

        expect(materialRepo.siteIds, contains('site-1'));
        expect(incidentRepo.siteIds, contains('site-1'));
        expect(attendanceRepo.siteIds, contains('site-1'));
      },
    );

    testWidgets('site cards flag low stock only for their own materials', (
      tester,
    ) async {
      final materialRepo = FakeMaterialRepository(
        initialMaterials: const [
          sp.Material(
            id: 'm1',
            name: 'Site 1 Cement',
            unit: 'bags',
            openingStock: 100,
            currentStock: 10,
            lowStockThreshold: 20,
            siteId: 'site-1',
          ),
          sp.Material(
            id: 'm2',
            name: 'Site 2 Gravel',
            unit: 'tons',
            openingStock: 100,
            currentStock: 80,
            lowStockThreshold: 20,
            siteId: 'site-2',
          ),
        ],
      );

      await tester.pumpWidget(buildDashboardApp(materialRepo: materialRepo));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('site_card_site-1')),
          matching: find.text('Low Stock Alert'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('site_card_site-2')),
          matching: find.text('Stock Healthy'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dashboard displays loading instead of default metric values', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDashboardApp(materialRepo: _NeverEmittingMaterialRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Loading dashboard metrics…'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(find.byKey(const Key('metric_low_stock')), findsNothing);
      expect(find.byKey(const Key('metric_high_incidents')), findsNothing);
    });
  });
}
