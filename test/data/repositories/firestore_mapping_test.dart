import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';

void main() {
  // ── Site.toFirestore / Site.fromFirestore ────────────────────────────

  group('Site Firestore mapping', () {
    test('toFirestore excludes id and hasPendingWrites', () {
      final site = Site(
        id: 'site-1',
        name: 'Downtown Heights',
        lastEntryAt: DateTime(2026, 10, 26, 14, 30),
        hasPendingWrites: true,
      );

      final map = site.toFirestore();

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('hasPendingWrites'), isFalse);
      expect(map['name'], 'Downtown Heights');
      expect(map.containsKey('lastEntryAt'), isTrue);
    });

    test('toFirestore omits lastEntryAt when null', () {
      const site = Site(id: 'site-2', name: 'New Site');
      final map = site.toFirestore();

      expect(map.containsKey('lastEntryAt'), isFalse);
      expect(map['name'], 'New Site');
    });

    test('fromFirestore round-trip via plain map', () {
      final site = Site.fromFirestore(
        'site-1',
        {'name': 'Metro', 'lastEntryAt': null},
        hasPendingWrites: true,
      );

      expect(site.id, 'site-1');
      expect(site.name, 'Metro');
      expect(site.lastEntryAt, isNull);
      expect(site.hasPendingWrites, isTrue);
    });

    test('fromFirestore with missing name defaults to empty string', () {
      final site = Site.fromFirestore('s-3', {});
      expect(site.id, 's-3');
      expect(site.name, '');
    });
  });

  // ── Worker.toFirestore / Worker.fromFirestore ───────────────────────

  group('Worker Firestore mapping', () {
    test('toFirestore excludes id, siteId, hasPendingWrites', () {
      const worker = Worker(
        id: 'w-1',
        name: 'Ramesh',
        trade: 'Mason',
        workerCode: 'MAS-01',
        active: true,
        siteId: 'site-1',
        hasPendingWrites: true,
      );

      final map = worker.toFirestore();

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('siteId'), isFalse);
      expect(map.containsKey('hasPendingWrites'), isFalse);
      expect(map['name'], 'Ramesh');
      expect(map['trade'], 'Mason');
      expect(map['workerCode'], 'MAS-01');
      expect(map['active'], isTrue);
    });

    test('fromFirestore injects docId and siteId from path', () {
      final worker = Worker.fromFirestore(
        'w-42',
        'site-x',
        {'name': 'Vikram', 'trade': 'Welder', 'workerCode': 'WEL-42', 'active': false},
        hasPendingWrites: true,
      );

      expect(worker.id, 'w-42');
      expect(worker.siteId, 'site-x');
      expect(worker.name, 'Vikram');
      expect(worker.trade, 'Welder');
      expect(worker.workerCode, 'WEL-42');
      expect(worker.active, isFalse);
      expect(worker.hasPendingWrites, isTrue);
    });

    test('fromFirestore defaults active to true when missing', () {
      final worker = Worker.fromFirestore(
        'w-99',
        'site-y',
        {'name': 'Test', 'trade': 'Helper', 'workerCode': 'HLP-99'},
      );
      expect(worker.active, isTrue);
      expect(worker.hasPendingWrites, isFalse);
    });
  });

  // ── AttendanceEntry dateKey / toFirestore / fromFirestore ────────────

  group('AttendanceEntry Firestore mapping', () {
    test('dateKeyFromDate formats correctly', () {
      expect(
        AttendanceEntry.dateKeyFromDate(DateTime(2026, 1, 5)),
        '2026-01-05',
      );
      expect(
        AttendanceEntry.dateKeyFromDate(DateTime(2026, 12, 31)),
        '2026-12-31',
      );
    });

    test('dateKeyFromDate pads single-digit month and day', () {
      expect(
        AttendanceEntry.dateKeyFromDate(DateTime(2026, 3, 9)),
        '2026-03-09',
      );
    });

    test('toFirestore contains expected Firestore fields', () {
      final entry = AttendanceEntry(
        id: 'site-1_w-1_20261026',
        workerId: 'w-1',
        date: DateTime(2026, 10, 26),
        status: AttendanceStatus.half,
        siteId: 'site-1',
      );

      final map = entry.toFirestore(createdBy: 'uid-sup1');

      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('siteId'), isFalse);
      expect(map.containsKey('hasPendingWrites'), isFalse);
      expect(map['workerId'], 'w-1');
      expect(map['status'], 'half');
      expect(map['dateKey'], '2026-10-26');
      expect(map['createdBy'], 'uid-sup1');
      expect(map.containsKey('updatedAt'), isTrue);
    });

    test('fromFirestore restores date from dateKey', () {
      final entry = AttendanceEntry.fromFirestore(
        'site-1_w-1_20261026',
        'site-1',
        {
          'workerId': 'w-1',
          'status': 'half',
          'dateKey': '2026-10-26',
          'createdBy': 'uid-sup1',
        },
        hasPendingWrites: true,
      );

      expect(entry.id, 'site-1_w-1_20261026');
      expect(entry.workerId, 'w-1');
      expect(entry.status, AttendanceStatus.half);
      expect(entry.siteId, 'site-1');
      expect(entry.date.year, 2026);
      expect(entry.date.month, 10);
      expect(entry.date.day, 26);
      expect(entry.hasPendingWrites, isTrue);
    });

    test('fromFirestore falls back when dateKey is null', () {
      final entry = AttendanceEntry.fromFirestore(
        'id-x',
        'site-2',
        {'workerId': 'w-2', 'status': 'present'},
      );

      // Falls back to DateTime.now() — just verify it doesn't crash
      expect(entry.id, 'id-x');
      expect(entry.siteId, 'site-2');
      expect(entry.status, AttendanceStatus.present);
    });

    test('buildId matches expected deterministic format', () {
      final id = AttendanceEntry.buildId(
        siteId: 'site_metro',
        workerId: 'w_site_metro_01',
        date: DateTime(2026, 10, 28),
      );
      expect(id, 'site_metro_w_site_metro_01_20261028');
    });
  });
}
