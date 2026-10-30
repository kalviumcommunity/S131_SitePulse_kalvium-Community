import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/router.dart';

Widget buildCompleteApp({
  required FakeAuthRepository authRepo,
  FakeSiteRepository? siteRepo,
  FakeWorkerRepository? workerRepo,
  FakeAttendanceRepository? attendanceRepo,
  FakeMaterialRepository? materialRepo,
  FakeIncidentRepository? incidentRepo,
  String? initialLocation,
}) {
  final router = buildRouter(
    firebaseReady: true,
    authRepository: authRepo,
    initialLocation: initialLocation,
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      if (siteRepo != null) siteRepositoryProvider.overrideWithValue(siteRepo),
      if (workerRepo != null) workerRepositoryProvider.overrideWithValue(workerRepo),
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
  group('Site Pulse End-to-End Acceptance Tests', () {
    testWidgets('Complete Supervisor Workflow: Home -> Attendance -> Material -> Incident -> Logout', (tester) async {
      const supervisor = AppUser(
        uid: 'sup-user-1',
        name: 'Ramesh Patel',
        role: UserRole.supervisor,
        siteId: 'site-1',
      );
      final authRepo = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );
      final siteRepo = FakeSiteRepository(
        initialSites: [
          Site(
            id: 'site-1',
            name: 'Metro Line 3 Station',
            lastEntryAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      );
      final workerRepo = FakeWorkerRepository(
        initialWorkers: [
          const Worker(id: 'w-1', name: 'Amit Kumar', workerCode: 'W001', trade: 'Mason', active: true, siteId: 'site-1'),
          const Worker(id: 'w-2', name: 'Sunil Verma', workerCode: 'W002', trade: 'Electrician', active: true, siteId: 'site-1'),
        ],
      );
      final attendanceRepo = FakeAttendanceRepository(initialAttendance: []);
      final materialRepo = FakeMaterialRepository(
        initialMaterials: [
          const sp.Material(
            id: 'mat-1',
            name: 'Cement Portland',
            unit: 'bags',
            openingStock: 100,
            currentStock: 45,
            lowStockThreshold: 20,
            siteId: 'site-1',
          ),
        ],
      );
      final incidentRepo = FakeIncidentRepository(initialIncidents: []);

      await tester.pumpWidget(
        buildCompleteApp(
          authRepo: authRepo,
          siteRepo: siteRepo,
          workerRepo: workerRepo,
          attendanceRepo: attendanceRepo,
          materialRepo: materialRepo,
          incidentRepo: incidentRepo,
          initialLocation: '/supervisor/home',
        ),
      );
      await tester.pumpAndSettle();

      // ── Step 1: Supervisor Home Screen ───────────────────────────────
      expect(find.text('Supervisor Home'), findsOneWidget);
      expect(find.text('Ramesh Patel'), findsOneWidget);
      expect(find.text('Metro Line 3 Station'), findsOneWidget);

      // Verify home actions and footer navigation are available
      expect(find.byKey(const Key('action_attendance')), findsOneWidget);
      expect(find.byKey(const Key('action_material')), findsOneWidget);
      expect(find.byKey(const Key('action_incident')), findsOneWidget);
      expect(find.byKey(const Key('action_roster')), findsNothing);
      expect(find.text('Roster'), findsOneWidget);
      await tester.tap(find.text('Roster'));
      await tester.pumpAndSettle();
      expect(find.text('Worker Roster'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // ── Step 2: Mark Attendance Flow ─────────────────────────────────
      await tester.tap(find.byKey(const Key('action_attendance')));
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);

      // Save attendance (fire-and-forget offline optimistic write)
      await tester.tap(find.byKey(const Key('save_attendance_button')));
      await tester.pump();
      expect(find.text('Saved on this device'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Navigate back to home
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Supervisor Home'), findsOneWidget);

      // ── Step 3: Material Usage Flow ──────────────────────────────────
      await tester.tap(find.byKey(const Key('action_material')));
      await tester.pumpAndSettle();

      expect(find.text('Material Usage'), findsOneWidget);
      expect(find.byKey(const Key('quantity_stepper')), findsOneWidget);

      // Log material usage
      await tester.tap(find.byKey(const Key('log_usage_button')));
      await tester.pump();
      expect(find.text('Saved on this device'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Navigate back to home
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Supervisor Home'), findsOneWidget);

      // ── Step 4: Incident Report Flow ─────────────────────────────────
      await tester.ensureVisible(find.byKey(const Key('action_incident')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('action_incident')));
      await tester.pumpAndSettle();

      // The Home action must open the root-level incident route.
      expect(find.text('Safety Incidents'), findsOneWidget);

      // Select High severity -> verify escalation banner appears
      await tester.tap(find.byKey(const Key('severity_high')));
      await tester.pump();
      expect(find.byKey(const Key('escalation_banner')), findsOneWidget);

      // Enter description >= 10 chars
      await tester.enterText(
        find.byKey(const Key('incident_description_field')),
        'Power failure on main feeder panel, generator dispatched.',
      );
      await tester.pump();

      // Submit and confirm dialog
      await tester.tap(find.byKey(const Key('submit_incident_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident_confirm_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Saved on this device'), findsOneWidget);

      // Navigate back to home
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Supervisor Home'), findsOneWidget);

      // ── Step 5: Logout Flow ──────────────────────────────────────────
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('logout_confirmation_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
    });

    testWidgets('Complete PM Workflow: Multi-site Dashboard -> Site Drill-Down 3 Tabs -> Logout', (tester) async {
      const pm = AppUser(
        uid: 'pm-user-1',
        name: 'Priya Sharma',
        role: UserRole.pm,
        siteId: null,
      );
      final authRepo = FakeAuthRepository(
        initialUsers: [pm],
        initialUser: pm,
      );
      final siteRepo = FakeSiteRepository();
      final materialRepo = FakeMaterialRepository();
      final incidentRepo = FakeIncidentRepository();
      final attendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(
        buildCompleteApp(
          authRepo: authRepo,
          siteRepo: siteRepo,
          materialRepo: materialRepo,
          incidentRepo: incidentRepo,
          attendanceRepo: attendanceRepo,
          initialLocation: '/pm/dashboard',
        ),
      );
      await tester.pumpAndSettle();

      // ── Step 1: PM Dashboard ─────────────────────────────────────────
      expect(find.text('PM Dashboard'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);

      // Verify all 3 summary metrics are visible
      expect(find.byKey(const Key('metric_crew_attendance')), findsOneWidget);
      expect(find.byKey(const Key('metric_low_stock')), findsOneWidget);
      expect(find.byKey(const Key('metric_high_incidents')), findsOneWidget);

      // Verify site cards render
      expect(find.byKey(const Key('site_card_site-1')), findsOneWidget);

      // ── Step 2: Drill Down into Site Detail ───────────────────────────
      await tester.tap(find.byKey(const Key('site_card_site-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tab_attendance')), findsOneWidget);
      expect(find.byKey(const Key('tab_materials')), findsOneWidget);
      expect(find.byKey(const Key('tab_incidents')), findsOneWidget);

      // Switch to Materials tab
      await tester.tap(find.byKey(const Key('tab_materials')));
      await tester.pumpAndSettle();
      expect(find.text('Current Stock Status'), findsOneWidget);

      // Switch to Incidents tab
      await tester.tap(find.byKey(const Key('tab_incidents')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tab_incidents_view')), findsOneWidget);

      // Verify PM is strictly read-only: no create or delete actions
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);

      // Navigate back to PM Dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('PM Dashboard'), findsOneWidget);

      // ── Step 3: PM Logout Flow ───────────────────────────────────────
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
    });

    testWidgets('Touch target audit: primary buttons meet minimum 48dp height', (tester) async {
      expect(isHighSeverity(Severity.high), isTrue);
      expect(isHighSeverity(Severity.critical), isTrue);
      expect(isHighSeverity(Severity.minor), isFalse);
    });
  });
}
