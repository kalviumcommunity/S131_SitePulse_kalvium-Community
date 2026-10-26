import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class AttendanceRepository {
  /// Reads attendance with optional site and date-range filters.
  /// Supervisor filters by own siteId and date.
  /// PM reads all sites (siteId = null) or specific site, with optional date range.
  Stream<List<AttendanceEntry>> watchAttendance({
    String? siteId,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Fire-and-forget write: returns attendance document ID immediately (siteId_workerId_yyyymmdd).
  /// Reports failures through errorStream.
  String recordAttendance(AttendanceEntry entry);

  /// Fire-and-forget batch write: returns list of document IDs immediately.
  List<String> recordBulkAttendance(List<AttendanceEntry> entries);

  Stream<RepositoryError> get errorStream;
}
