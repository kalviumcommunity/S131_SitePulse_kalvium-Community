import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/models.dart';

void main() {
  group('Models toMap / fromMap round-trip', () {
    test('AppUser round-trip', () {
      final user = const AppUser(
        uid: 'user-1',
        role: UserRole.supervisor,
        name: 'John Supervisor',
        siteId: 'site-alpha',
        hasPendingWrites: true,
      );

      final map = user.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.uid, user.uid);
      expect(restored.role, user.role);
      expect(restored.name, user.name);
      expect(restored.siteId, user.siteId);
      expect(restored.hasPendingWrites, user.hasPendingWrites);
      expect(restored, equals(user));
    });

    test('AppUser with null siteId and default hasPendingWrites round-trip', () {
      final user = const AppUser(
        uid: 'user-pm',
        role: UserRole.pm,
        name: 'Alice PM',
      );

      final map = user.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.uid, user.uid);
      expect(restored.role, UserRole.pm);
      expect(restored.name, user.name);
      expect(restored.siteId, isNull);
      expect(restored.hasPendingWrites, isFalse);
      expect(restored, equals(user));
    });

    test('Site round-trip', () {
      final now = DateTime.now();
      final site = Site(
        id: 'site-1',
        name: 'Downtown Heights',
        lastEntryAt: now,
        hasPendingWrites: true,
      );

      final map = site.toMap();
      final restored = Site.fromMap(map);

      expect(restored.id, site.id);
      expect(restored.name, site.name);
      expect(restored.lastEntryAt?.toIso8601String(), site.lastEntryAt?.toIso8601String());
      expect(restored.hasPendingWrites, isTrue);
    });

    test('Site with null lastEntryAt round-trip', () {
      const site = Site(
        id: 'site-2',
        name: 'New Site',
      );

      final map = site.toMap();
      final restored = Site.fromMap(map);

      expect(restored.id, site.id);
      expect(restored.name, site.name);
      expect(restored.lastEntryAt, isNull);
      expect(restored.hasPendingWrites, isFalse);
      expect(restored, equals(site));
    });

    test('Worker round-trip', () {
      const worker = Worker(
        id: 'w-1',
        name: 'David Carpenter',
        trade: 'Carpenter',
        workerCode: 'CAR-101',
        active: true,
        siteId: 'site-1',
        hasPendingWrites: true,
      );

      final map = worker.toMap();
      final restored = Worker.fromMap(map);

      expect(restored.id, worker.id);
      expect(restored.name, worker.name);
      expect(restored.trade, worker.trade);
      expect(restored.workerCode, worker.workerCode);
      expect(restored.active, worker.active);
      expect(restored.siteId, worker.siteId);
      expect(restored.hasPendingWrites, isTrue);
      expect(restored, equals(worker));
    });

    test('AttendanceEntry round-trip', () {
      final date = DateTime(2026, 10, 26);
      final id = AttendanceEntry.buildId(
        siteId: 'site-1',
        workerId: 'w-1',
        date: date,
      );

      final entry = AttendanceEntry(
        id: id,
        workerId: 'w-1',
        date: date,
        status: AttendanceStatus.half,
        siteId: 'site-1',
        hasPendingWrites: true,
      );

      final map = entry.toMap();
      final restored = AttendanceEntry.fromMap(map);

      expect(restored.id, entry.id);
      expect(restored.workerId, entry.workerId);
      expect(restored.date.year, entry.date.year);
      expect(restored.date.month, entry.date.month);
      expect(restored.date.day, entry.date.day);
      expect(restored.status, AttendanceStatus.half);
      expect(restored.effectiveSiteId, 'site-1');
      expect(restored.hasPendingWrites, isTrue);
      expect(restored, equals(entry));
    });

    test('Material round-trip', () {
      const material = Material(
        id: 'mat-1',
        name: 'Portland Cement',
        unit: 'bags',
        openingStock: 100,
        currentStock: 15.5,
        lowStockThreshold: 25,
        hasPendingWrites: true,
      );

      final map = material.toMap();
      final restored = Material.fromMap(map);

      expect(restored.id, material.id);
      expect(restored.name, material.name);
      expect(restored.unit, material.unit);
      expect(restored.openingStock, 100.0);
      expect(restored.currentStock, 15.5);
      expect(restored.lowStockThreshold, 25.0);
      expect(restored.hasPendingWrites, isTrue);
      expect(restored, equals(material));
    });

    test('MaterialLog round-trip', () {
      final now = DateTime.now();
      final log = MaterialLog(
        id: 'log-1',
        materialId: 'mat-1',
        qtyUsed: 10.5,
        remainingAfter: 89.5,
        date: now,
        hasPendingWrites: true,
      );

      final map = log.toMap();
      final restored = MaterialLog.fromMap(map);

      expect(restored.id, log.id);
      expect(restored.materialId, log.materialId);
      expect(restored.qtyUsed, 10.5);
      expect(restored.remainingAfter, 89.5);
      expect(restored.date.toIso8601String(), log.date.toIso8601String());
      expect(restored.hasPendingWrites, isTrue);
      expect(restored, equals(log));
    });

    test('Incident round-trip', () {
      final now = DateTime.now();
      final incident = Incident(
        id: 'inc-1',
        severity: Severity.high,
        description: 'Scaffolding collapse near Gate 2',
        occurredAt: now,
        siteId: 'site-1',
        hasPendingWrites: true,
      );

      final map = incident.toMap();
      final restored = Incident.fromMap(map);

      expect(restored.id, incident.id);
      expect(restored.severity, Severity.high);
      expect(restored.description, incident.description);
      expect(restored.occurredAt.toIso8601String(), incident.occurredAt.toIso8601String());
      expect(restored.siteId, 'site-1');
      expect(restored.hasPendingWrites, isTrue);
      expect(restored, equals(incident));
    });
  });
}
