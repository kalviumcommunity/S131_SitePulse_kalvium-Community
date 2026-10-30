import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class AttendanceRepository {
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns immediately and reports queued-write failures through [errorStream].
  String recordAttendance(AttendanceEntry entry);

  /// Returns ids immediately so callers never wait for offline writes.
  List<String> recordBulkAttendance(List<AttendanceEntry> entries);

  Stream<RepositoryError> get errorStream;
}
