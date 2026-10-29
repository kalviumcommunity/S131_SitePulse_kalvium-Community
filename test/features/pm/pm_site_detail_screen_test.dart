import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/features/pm/site_detail/pm_site_detail_screen.dart';

class _CustomMaterialLogsRepository extends FakeMaterialRepository {
  _CustomMaterialLogsRepository(this._logs);

  final Stream<List<MaterialLog>> _logs;

  @override
  Stream<List<MaterialLog>> watchMaterialLogs({
    String? siteId,
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _logs;
  }
}

Widget buildSiteDetailApp({
  String siteId = 'site-1',
  FakeSiteRepository? siteRepo,
  FakeAttendanceRepository? attendanceRepo,
  FakeMaterialRepository? materialRepo,
  FakeIncidentRepository? incidentRepo,
  FakeWorkerRepository? workerRepo,
}) {
  const pmUser = AppUser(
    uid: 'pm-1',
    name: 'Priya Sharma',
    role: UserRole.pm,
    siteId: null,
  );
  final actualAuth = FakeAuthRepository(
    initialUser: pmUser,
    initialUsers: [pmUser],
  );
  final actualSite =
      siteRepo ??
      FakeSiteRepository(
        initialSites: [
          Site(
            id: 'site-1',
            name: 'Downtown Heights',
            lastEntryAt: DateTime.now(),
          ),
        ],
      );
  final actualAttendance = attendanceRepo ?? FakeAttendanceRepository();
  final actualMaterial = materialRepo ?? FakeMaterialRepository();
  final actualIncident = incidentRepo ?? FakeIncidentRepository();
  final actualWorker = workerRepo ?? FakeWorkerRepository();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(actualAuth),
      siteRepositoryProvider.overrideWithValue(actualSite),
      attendanceRepositoryProvider.overrideWithValue(actualAttendance),
      materialRepositoryProvider.overrideWithValue(actualMaterial),
      incidentRepositoryProvider.overrideWithValue(actualIncident),
      workerRepositoryProvider.overrideWithValue(actualWorker),
    ],
    child: MaterialApp(home: PmSiteDetailScreen(siteId: siteId)),
  );
}

void main() {
  group('PmSiteDetailScreen Widget Tests', () {
    testWidgets('renders site name in AppBar and 3 tabs', (tester) async {
      await tester.pumpWidget(buildSiteDetailApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Downtown Heights'), findsOneWidget);
      expect(find.byKey(const Key('tab_attendance')), findsOneWidget);
      expect(find.byKey(const Key('tab_materials')), findsOneWidget);
      expect(find.byKey(const Key('tab_incidents')), findsOneWidget);
    });

    testWidgets('attendance tab displays day card and expands worker details', (
      tester,
    ) async {
      await tester.pumpWidget(buildSiteDetailApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('tab_attendance_view')), findsOneWidget);
      expect(find.byType(ExpansionTile), findsWidgets);

      // Tap first expansion tile to view worker breakdown
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(find.text('PRESENT'), findsWidgets);
    });

    testWidgets(
      'switching to materials tab displays stock cards and usage logs',
      (tester) async {
        await tester.pumpWidget(buildSiteDetailApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Materials Tab
        await tester.tap(find.byKey(const Key('tab_materials')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tab_materials_view')), findsOneWidget);
        expect(find.text('Current Stock Status'), findsOneWidget);
        expect(find.text('Recent Material Usage Logs'), findsOneWidget);
      },
    );

    testWidgets(
      'switching to incidents tab displays incidents list with severity badges',
      (tester) async {
        await tester.pumpWidget(buildSiteDetailApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Incidents Tab
        await tester.tap(find.byKey(const Key('tab_incidents')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tab_incidents_view')), findsOneWidget);
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('ESCALATED'), findsOneWidget);
      },
    );

    testWidgets(
      'read-only: no floating action button or delete buttons exist for PM',
      (tester) async {
        await tester.pumpWidget(buildSiteDetailApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.byIcon(Icons.delete), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
      },
    );

    testWidgets(
      'shows empty state when no attendance records exist for date range',
      (tester) async {
        final emptyAttendance = FakeAttendanceRepository(initialAttendance: []);
        await tester.pumpWidget(
          buildSiteDetailApp(attendanceRepo: emptyAttendance),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('No attendance records found for this period.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('material logs show loading while their stream is pending', (
      tester,
    ) async {
      final repository = _CustomMaterialLogsRepository(
        Stream<List<MaterialLog>>.multi((_) {}),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(buildSiteDetailApp(materialRepo: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_materials')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Recent Material Usage Logs'), findsOneWidget);
      expect(find.text('Loading material logs…'), findsOneWidget);
      expect(
        find.text('No material usage logged in this date range.'),
        findsNothing,
      );
    });

    testWidgets('material log errors are shown instead of an empty state', (
      tester,
    ) async {
      final repository = _CustomMaterialLogsRepository(
        Stream<List<MaterialLog>>.error(StateError('logs unavailable')),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(buildSiteDetailApp(materialRepo: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_materials')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Recent Material Usage Logs'), findsOneWidget);
      expect(
        find.textContaining('Failed to load material logs:'),
        findsOneWidget,
      );
      expect(
        find.text('No material usage logged in this date range.'),
        findsNothing,
      );
    });
  });
}
