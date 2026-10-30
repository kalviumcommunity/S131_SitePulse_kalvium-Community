import 'dart:async';

import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  final Map<String, AttendanceEntry> _attendance = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeAttendanceRepository({List<AttendanceEntry>? initialAttendance}) {
    if (initialAttendance != null) {
      for (final a in initialAttendance) {
        _attendance[a.id] = a;
      }
    } else {
      final today = DateTime.now();
      _seedDefaultAttendance(today);
    }
  }

  void _seedDefaultAttendance(DateTime date) {
    final seedWorkersSite1 = ['w-101', 'w-102', 'w-103', 'w-104', 'w-105'];
    for (var i = 0; i < seedWorkersSite1.length; i++) {
      final wId = seedWorkersSite1[i];
      final id = AttendanceEntry.buildId(
        siteId: 'site-1',
        workerId: wId,
        date: date,
      );
      final status = i == 3
          ? AttendanceStatus.half
          : (i == 4 ? AttendanceStatus.absent : AttendanceStatus.present);
      _attendance[id] = AttendanceEntry(
        id: id,
        workerId: wId,
        date: date,
        status: status,
        siteId: 'site-1',
      );
    }
  }

  @override
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) async* {
    yield _filter(
      siteId: siteId,
      date: date,
      startDate: startDate,
      endDate: endDate,
    );
    yield* _changeController.stream.map(
      (_) => _filter(
        siteId: siteId,
        date: date,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  List<AttendanceEntry> _filter({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _attendance.values.where((entry) {
      if (siteId != null && entry.effectiveSiteId != siteId) {
        return false;
      }
      if (date != null) {
        if (entry.date.year != date.year ||
            entry.date.month != date.month ||
            entry.date.day != date.day) {
          return false;
        }
      }
      if (startDate != null) {
        final startDay = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final entryDay = DateTime(
          entry.date.year,
          entry.date.month,
          entry.date.day,
        );
        if (entryDay.isBefore(startDay)) return false;
      }
      if (endDate != null) {
        final endDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        if (entry.date.isAfter(endDay)) return false;
      }
      return true;
    }).toList();
  }

  @override
  String recordAttendance(AttendanceEntry entry) {
    final sId = entry.effectiveSiteId;
    if (sId.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'recordAttendance',
          message: 'Attendance entry must have a valid siteId',
        ),
      );
      return entry.id;
    }
    if (entry.workerId.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'recordAttendance',
          message: 'Attendance entry must have a valid workerId',
        ),
      );
      return entry.id;
    }

    final id = entry.id.isNotEmpty
        ? entry.id
        : AttendanceEntry.buildId(
            siteId: sId,
            workerId: entry.workerId,
            date: entry.date,
          );

    final toSave = entry.id == id && entry.siteId == sId
        ? entry
        : entry.copyWith(id: id, siteId: sId);

    _attendance[id] = toSave;
    _changeController.add(null);
    return id;
  }

  @override
  List<String> recordBulkAttendance(List<AttendanceEntry> entries) {
    final ids = <String>[];
    for (final entry in entries) {
      ids.add(recordAttendance(entry));
    }
    return ids;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _changeController.close();
    _errorController.close();
  }
}
