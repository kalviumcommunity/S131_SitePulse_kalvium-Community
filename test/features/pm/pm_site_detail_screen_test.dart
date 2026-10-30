import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/features/pm/site_detail/pm_site_detail_screen.dart';
import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';

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

class _TrackingAttendanceRepository extends FakeAttendanceRepository {
  _TrackingAttendanceRepository({super.initialAttendance});

  DateTime? startDate;
  DateTime? endDate;

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    this.startDate = startDate;
    this.endDate = endDate;
    return super.watchAttendance(
      siteId: siteId,
      date: date,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

class _CustomAttendanceRepository extends FakeAttendanceRepository {
  _CustomAttendanceRepository(this._records);

  final Stream<List<AttendanceEntry>> _records;

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _records;
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
    overrides: fakeRepositoryOverrides(
      authRepository: actualAuth,
      siteRepository: actualSite,
      attendanceRepository: actualAttendance,
      materialRepository: actualMaterial,
      incidentRepository: actualIncident,
      workerRepository: actualWorker,
    ),
    child: MaterialApp(home: PmSiteDetailScreen(siteId: siteId)),
  );
}

void main() {
  group('PmSiteDetailScreen Widget Tests', () {
    testWidgets('attendance chart renders one bar per day for a week', (
      tester,
    ) async {
      final today = DateTime.now();
      final repository = FakeAttendanceRepository(
        initialAttendance: [
          AttendanceEntry(
            id: 'attendance-today',
            workerId: 'worker-1',
            date: today,
            status: AttendanceStatus.present,
            siteId: 'site-1',
          ),
        ],
      );
      await tester.pumpWidget(
        buildSiteDetailApp(attendanceRepo: repository),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('attendance_chart')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'attendance_chart_bar_',
              ),
        ),
        findsNWidgets(7),
      );
      expect(
        find.byKey(
          Key(
            'attendance_chart_bar_${AttendanceEntry.dateKeyFromDate(today)}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'attendance_chart_bar_${AttendanceEntry.dateKeyFromDate(
              today.subtract(const Duration(days: 6)),
            )}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Half-day'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('Month toggle changes attendance query to last 30 days', (
      tester,
    ) async {
      final repository = _TrackingAttendanceRepository(
        initialAttendance: [
          AttendanceEntry(
            id: 'attendance-today',
            workerId: 'worker-1',
            date: DateTime.now(),
            status: AttendanceStatus.present,
            siteId: 'site-1',
          ),
        ],
      );
      await tester.pumpWidget(
        buildSiteDetailApp(attendanceRepo: repository),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.startDate, isNotNull);
      expect(repository.endDate, isNotNull);
      expect(repository.endDate!.difference(repository.startDate!).inDays, 29);
      expect(repository.startDate!.hour, 0);
      expect(repository.endDate!.hour, 23);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key as ValueKey<String>).value.startsWith(
                'attendance_chart_bar_',
              ),
        ),
        findsNWidgets(30),
      );
    });

    testWidgets('attendance loading and empty states render', (tester) async {
      final pendingRepository = _CustomAttendanceRepository(
        Stream<List<AttendanceEntry>>.multi((_) {}),
      );
      addTearDown(pendingRepository.dispose);
      await tester.pumpWidget(
        buildSiteDetailApp(attendanceRepo: pendingRepository),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Loading attendance history…'), findsOneWidget);
      expect(find.byKey(const Key('attendance_chart')), findsNothing);

      await tester.pumpWidget(
        buildSiteDetailApp(
          attendanceRepo: FakeAttendanceRepository(initialAttendance: []),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('No attendance records found for this period.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('attendance_chart')), findsNothing);
    });

    testWidgets('site detail has title, back button and 3 bottom tabs', (
      tester,
    ) async {
      await tester.pumpWidget(buildSiteDetailApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Downtown Heights'), findsOneWidget);
      expect(find.byKey(const Key('pm_site_back')), findsOneWidget);
      expect(find.byKey(const Key('tab_attendance')), findsOneWidget);
      expect(find.byKey(const Key('tab_materials')), findsOneWidget);
      expect(find.byKey(const Key('tab_incidents')), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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
