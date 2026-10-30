import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/firestore_site_repository.dart';

/// Local yyyy-MM-dd date keys preserve calendar-day ranges without timezone drift.
class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this._defaultLimit = 1500,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final int _defaultLimit;

  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  CollectionReference<Map<String, dynamic>> _attendanceCol(String siteId) =>
      _db.collection('sites').doc(siteId).collection('attendance');

  String get _currentUid => _auth.currentUser?.uid ?? '';

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (date == null && (startDate == null || endDate == null)) {
      return Stream.error(
        ArgumentError(
          'Attendance reads require a day or a complete date range',
        ),
      );
    }

    if (siteId != null) {
      return _watchSiteAttendance(
        siteId: siteId,
        date: date,
        startDate: startDate,
        endDate: endDate,
      );
    }

    return _watchAllSitesAttendance(
      date: date,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Stream<List<AttendanceEntry>> _watchSiteAttendance({
    required String siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query<Map<String, dynamic>> query = _attendanceCol(siteId);

    if (date != null) {
      final dateKey = AttendanceEntry.dateKeyFromDate(date);
      query = query
          .where('dateKey', isGreaterThanOrEqualTo: dateKey)
          .where('dateKey', isLessThanOrEqualTo: dateKey);
    } else {
      if (startDate != null) {
        final fromKey = AttendanceEntry.dateKeyFromDate(startDate);
        query = query.where('dateKey', isGreaterThanOrEqualTo: fromKey);
      }
      if (endDate != null) {
        final toKey = AttendanceEntry.dateKeyFromDate(endDate);
        query = query.where('dateKey', isLessThanOrEqualTo: toKey);
      }
    }

    query = query.limit(_defaultLimit);

    return query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => snap.docs.map((doc) {
            return AttendanceEntry.fromFirestore(
              doc.id,
              siteId,
              doc.data(),
              hasPendingWrites: doc.metadata.hasPendingWrites,
            );
          }).toList(),
        );
  }

  Stream<List<AttendanceEntry>> _watchAllSitesAttendance({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return combineSiteStreams(
      watchAllSites(_db),
      (siteId) => _watchSiteAttendance(
        siteId: siteId,
        date: date,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  @override
  String recordAttendance(AttendanceEntry entry) {
    final siteId = entry.effectiveSiteId;
    if (siteId.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'recordAttendance',
          message: 'Attendance entry must have a valid siteId',
        ),
      );
      return entry.id;
    }

    final id = AttendanceEntry.buildId(
      siteId: siteId,
      workerId: entry.workerId,
      date: entry.date,
    );

    final uid = _currentUid;
    if (uid.isEmpty) {
      _errorController.add(
        RepositoryError(
          operation: 'recordAttendance',
          message: 'A signed-in user is required to record attendance',
          documentId: id,
        ),
      );
      return id;
    }

    final batch = _db.batch();

    batch.set(
      _attendanceCol(siteId).doc(id),
      entry.toFirestore(createdBy: uid),
      SetOptions(merge: true),
    );

    batch.set(_db.collection('sites').doc(siteId), {
      'lastEntryAt': Timestamp.now(),
    }, SetOptions(merge: true));

    batch.commit().then(
      (_) {},
      onError: (Object e, StackTrace st) =>
          _reportWriteFailure('recordAttendance', id, e, st),
    );
    return id;
  }

  @override
  List<String> recordBulkAttendance(List<AttendanceEntry> entries) {
    if (entries.isEmpty) return [];

    final ids = <String>[];
    final uid = _currentUid;
    if (uid.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'recordBulkAttendance',
          message: 'A signed-in user is required to record attendance',
        ),
      );
      return entries
          .map(
            (entry) => AttendanceEntry.buildId(
              siteId: entry.effectiveSiteId,
              workerId: entry.workerId,
              date: entry.date,
            ),
          )
          .toList();
    }

    final batch = _db.batch();
    final updatedSiteIds = <String>{};

    for (final entry in entries) {
      final siteId = entry.effectiveSiteId;
      if (siteId.isEmpty) {
        _errorController.add(
          RepositoryError(
            operation: 'recordBulkAttendance',
            message: 'Attendance entry must have a valid siteId',
            documentId: entry.id,
          ),
        );
        ids.add(entry.id);
        continue;
      }

      final id = AttendanceEntry.buildId(
        siteId: siteId,
        workerId: entry.workerId,
        date: entry.date,
      );

      batch.set(
        _attendanceCol(siteId).doc(id),
        entry.toFirestore(createdBy: uid),
        SetOptions(merge: true),
      );
      updatedSiteIds.add(siteId);
      ids.add(id);
    }

    final now = Timestamp.now();
    for (final siteId in updatedSiteIds) {
      batch.set(_db.collection('sites').doc(siteId), {
        'lastEntryAt': now,
      }, SetOptions(merge: true));
    }

    if (updatedSiteIds.isEmpty) return ids;

    batch.commit().then(
      (_) {},
      onError: (Object e, StackTrace st) =>
          _reportWriteFailure('recordBulkAttendance', ids.join(','), e, st),
    );

    return ids;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void _reportWriteFailure(
    String operation,
    String docId,
    Object error,
    StackTrace stackTrace,
  ) {
    _errorController.add(
      RepositoryError(
        operation: operation,
        message: error.toString(),
        error: error,
        stackTrace: stackTrace,
        documentId: docId,
      ),
    );
  }

  void dispose() {
    _errorController.close();
  }
}
