import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/data/models/models.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';

import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';

void main() {
  group('Fake Repositories & Riverpod Providers', () {
    testWidgets('Riverpod provides all fake repositories', (tester) async {
      late AuthRepository authRepository;
      late SiteRepository siteRepository;
      late WorkerRepository workerRepository;
      late AttendanceRepository attendanceRepository;
      late MaterialRepository materialRepository;
      late IncidentRepository incidentRepository;

      await tester.pumpWidget(
        ProviderScope(
          overrides: fakeRepositoryOverrides(),
          child: Consumer(
            builder: (context, ref, child) {
              authRepository = ref.watch(authRepositoryProvider);
              siteRepository = ref.watch(siteRepositoryProvider);
              workerRepository = ref.watch(workerRepositoryProvider);
              attendanceRepository = ref.watch(attendanceRepositoryProvider);
              materialRepository = ref.watch(materialRepositoryProvider);
              incidentRepository = ref.watch(incidentRepositoryProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(authRepository, isA<AuthRepository>());
      expect(siteRepository, isA<SiteRepository>());
      expect(workerRepository, isA<WorkerRepository>());
      expect(attendanceRepository, isA<AttendanceRepository>());
      expect(materialRepository, isA<MaterialRepository>());
      expect(incidentRepository, isA<IncidentRepository>());
    });

    test('SiteRepository is seeded with 3 sites', () async {
      final repo = FakeSiteRepository();
      final sites = await repo.watchSites().first;

      expect(sites.length, 3);
      expect(
        sites.map((s) => s.id),
        containsAll(['site-1', 'site-2', 'site-3']),
      );
    });

    test(
      'WorkerRepository is seeded with ~10 workers each for 3 sites',
      () async {
        final repo = FakeWorkerRepository();
        final site1Workers = await repo.watchWorkers('site-1').first;
        final site2Workers = await repo.watchWorkers('site-2').first;
        final site3Workers = await repo.watchWorkers('site-3').first;
        final allWorkers = await repo.watchAllWorkers().first;

        expect(site1Workers.length, 10);
        expect(site2Workers.length, 10);
        expect(site3Workers.length, 10);
        expect(allWorkers.length, 30);
      },
    );

    test('MaterialRepository is seeded with materials having at least one below threshold', () async {
      final repo = FakeMaterialRepository();
      final materials = await repo.watchMaterials().first;

      expect(materials.isNotEmpty, isTrue);
      final lowStockMaterials = materials.where(isLowStock).toList();
      expect(lowStockMaterials.length, greaterThanOrEqualTo(1));
      expect(lowStockMaterials.first.id, 'mat-1');
    });

    test('MaterialRepository logUsage decrements currentStock and logs usage in one operation', () async {
      final repo = FakeMaterialRepository();
      final initial = await repo.watchMaterial('mat-2').first;
      expect(initial, isNotNull);
      final initialStock = initial!.currentStock;

      // Fire and forget write returns id immediately
      final logId = repo.logUsage(materialId: 'mat-2', qtyUsed: 10.0);
      expect(logId, isNotEmpty);

      final updated = await repo.watchMaterial('mat-2').first;
      expect(updated?.currentStock, initialStock - 10.0);

      final logs = await repo.watchMaterialLogs(materialId: 'mat-2').first;
      expect(logs.any((l) => l.id == logId && l.qtyUsed == 10.0), isTrue);
    });

    test(
      'material lookups and usage writes are scoped by site and material id',
      () async {
        final repo = FakeMaterialRepository(
          initialMaterials: const [
            Material(
              id: 'mat_shared',
              name: 'Site A cement',
              unit: 'bags',
              openingStock: 100,
              currentStock: 10,
              lowStockThreshold: 5,
              siteId: 'site-a',
            ),
            Material(
              id: 'mat_shared',
              name: 'Site B cement',
              unit: 'bags',
              openingStock: 100,
              currentStock: 20,
              lowStockThreshold: 5,
              siteId: 'site-b',
            ),
          ],
        );

        final siteAMaterials = await repo
            .watchMaterials(siteId: 'site-a')
            .first;
        final siteAMaterial = await repo
            .watchMaterial('mat_shared', siteId: 'site-a')
            .first;
        final siteBMaterial = await repo
            .watchMaterial('mat_shared', siteId: 'site-b')
            .first;
        final logId = repo.logUsage(
          materialId: 'mat_shared',
          siteId: 'site-b',
          qtyUsed: 2,
        );
        final updatedSiteB = await repo
            .watchMaterial('mat_shared', siteId: 'site-b')
            .first;
        final updatedSiteA = await repo
            .watchMaterial('mat_shared', siteId: 'site-a')
            .first;
        final siteBLogs = await repo.watchMaterialLogs(siteId: 'site-b').first;

        expect(siteAMaterials, hasLength(1));
        expect(siteAMaterial?.name, 'Site A cement');
        expect(siteBMaterial?.name, 'Site B cement');
        expect(updatedSiteB?.currentStock, 18);
        expect(updatedSiteA?.currentStock, 10);
        expect(siteBLogs.any((log) => log.id == logId), isTrue);
      },
    );

    test(
      'IncidentRepository is seeded with 2 incidents (one high severity)',
      () async {
        final repo = FakeIncidentRepository();
        final incidents = await repo.watchIncidents().first;

        expect(incidents.length, 2);
        final highIncidents = incidents
            .where((inc) => isHighSeverity(inc.severity))
            .toList();
        expect(highIncidents.length, 1);
        expect(highIncidents.first.severity, Severity.high);
      },
    );

    test('AttendanceRepository uses siteId_workerId_yyyymmdd and returns id immediately', () async {
      final repo = FakeAttendanceRepository();
      final date = DateTime(2026, 10, 26);
      const siteId = 'site-1';
      const workerId = 'w-109';
      final expectedId = '${siteId}_${workerId}_20261026';

      final entry = AttendanceEntry(
        id: expectedId,
        workerId: workerId,
        date: date,
        status: AttendanceStatus.present,
        siteId: siteId,
      );

      final returnedId = repo.recordAttendance(entry);
      expect(returnedId, expectedId);

      final attendanceList = await repo
          .watchAttendance(siteId: siteId, date: date)
          .first;
      expect(attendanceList.any((a) => a.id == expectedId), isTrue);
    });

    test(
      'Repository writes report failures through errorStream without awaiting',
      () async {
        final repo = FakeMaterialRepository();
        final errors = <RepositoryError>[];
        final sub = repo.errorStream.listen(errors.add);
        addTearDown(sub.cancel);

        // Invalid materialId: should emit error to stream
        final logId = repo.logUsage(materialId: 'non-existent', qtyUsed: 5.0);
        expect(logId, isNotEmpty);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(errors.isNotEmpty, isTrue);
        expect(errors.first.operation, 'logUsage');
      },
    );
  });
}
