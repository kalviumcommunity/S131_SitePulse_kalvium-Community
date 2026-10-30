import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/features/supervisor/attendance/attendance_screen.dart';
import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';

class _CountingWorkerRepository extends FakeWorkerRepository {
  int watchWorkersCalls = 0;

  @override
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly}) {
    watchWorkersCalls++;
    return super.watchWorkers(siteId, activeOnly: activeOnly);
  }
}

class _CountingAttendanceRepository extends FakeAttendanceRepository {
  int watchAttendanceCalls = 0;

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    watchAttendanceCalls++;
    return super.watchAttendance(
      siteId: siteId,
      date: date,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

void main() {
  // Supervisor user for site-1 (seeded with workers w-101..w-110)
  const supUser = AppUser(
    uid: 'user-sup-1',
    role: UserRole.supervisor,
    name: 'Test Supervisor',
    siteId: 'site-1',
  );

  Widget buildScreen({AppUser user = supUser}) {
    return ProviderScope(
      overrides: fakeRepositoryOverrides(
        authRepository: FakeAuthRepository(initialUser: user),
      ),
      child: const MaterialApp(home: AttendanceScreen()),
    );
  }

  group('AttendanceScreen Widget Tests', () {
    testWidgets('signed-out user makes no repository query', (tester) async {
      final authRepository = FakeAuthRepository()..signOut();
      final workerRepository = _CountingWorkerRepository();
      final attendanceRepository = _CountingAttendanceRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: fakeRepositoryOverrides(
            authRepository: authRepository,
            workerRepository: workerRepository,
            attendanceRepository: attendanceRepository,
          ),
          child: const MaterialApp(home: AttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No project site is assigned to this account.'),
        findsOneWidget,
      );
      expect(workerRepository.watchWorkersCalls, 0);
      expect(attendanceRepository.watchAttendanceCalls, 0);
    });

    testWidgets('renders date picker button with "Today" label', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('date_picker_button')), findsOneWidget);
      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('shows Present, Half, Absent counter chips', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('counter_present')), findsOneWidget);
      expect(find.byKey(const Key('counter_half')), findsOneWidget);
      expect(find.byKey(const Key('counter_absent')), findsOneWidget);
    });

    testWidgets('shows Save Attendance button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('save_attendance_button')), findsOneWidget);
    });

    testWidgets('tapping Save shows "Saved on this device" snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('save_attendance_button')));
      await tester.pump(); // build snackbar

      expect(find.text('Saved on this device'), findsOneWidget);
    });

    testWidgets('shows empty view for a site with no workers', (tester) async {
      const emptyUser = AppUser(
        uid: 'user-sup-empty',
        role: UserRole.supervisor,
        name: 'Empty Supervisor',
        siteId: 'site-nonexistent-999',
      );

      await tester.pumpWidget(buildScreen(user: emptyUser));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('No active workers'), findsOneWidget);
    });

    testWidgets('each worker has an AttendanceToggle and SyncChip', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // FakeWorkerRepository seeds workers w-101..w-110 for site-1
      // At least some toggles and chips must be visible
      expect(find.byKey(const Key('attendance_toggle_w-101')), findsOneWidget);
      expect(find.byKey(const Key('sync_chip_w-101')), findsOneWidget);
    });
  });

  group('AttendanceEntry Model Tests', () {
    test('buildId generates deterministic siteId_workerId_yyyymmdd', () {
      final id = AttendanceEntry.buildId(
        siteId: 'site-1',
        workerId: 'w-101',
        date: DateTime(2024, 3, 7),
      );
      expect(id, 'site-1_w-101_20240307');
    });

    test('buildId zero-pads month and day', () {
      final id = AttendanceEntry.buildId(
        siteId: 'site-2',
        workerId: 'w-5',
        date: DateTime(2025, 1, 5),
      );
      expect(id, 'site-2_w-5_20250105');
    });

    test('fromMap round-trips through toMap', () {
      final entry = AttendanceEntry(
        id: 'site-1_w-101_20240307',
        workerId: 'w-101',
        date: DateTime.utc(2024, 3, 7),
        status: AttendanceStatus.half,
        siteId: 'site-1',
      );
      final map = entry.toMap();
      final restored = AttendanceEntry.fromMap(map);
      expect(restored.workerId, entry.workerId);
      expect(restored.status, AttendanceStatus.half);
      expect(restored.siteId, 'site-1');
    });

    test('effectiveSiteId falls back to parsing id prefix', () {
      final entry = AttendanceEntry(
        id: 'site-2_w-200_20240101',
        workerId: 'w-200',
        date: DateTime.utc(2024, 1, 1),
        status: AttendanceStatus.present,
      );
      expect(entry.effectiveSiteId, 'site-2');
    });

    test('AttendanceStatus.fromString is case-insensitive', () {
      expect(AttendanceStatus.fromString('PRESENT'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('Half'), AttendanceStatus.half);
      expect(AttendanceStatus.fromString('absent'), AttendanceStatus.absent);
    });

    test(
      'FakeAttendanceRepository recordAttendance stores and retrieves',
      () async {
        final repo = FakeAttendanceRepository();
        final entry = AttendanceEntry(
          id: AttendanceEntry.buildId(
            siteId: 'site-1',
            workerId: 'w-999',
            date: DateTime(2024, 6, 1),
          ),
          workerId: 'w-999',
          date: DateTime(2024, 6, 1),
          status: AttendanceStatus.absent,
          siteId: 'site-1',
        );

        final id = repo.recordAttendance(entry);
        expect(id, 'site-1_w-999_20240601');

        final all = await repo
            .watchAttendance(siteId: 'site-1', date: DateTime(2024, 6, 1))
            .first;
        expect(all.any((e) => e.workerId == 'w-999'), isTrue);
      },
    );
  });
}
