import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is Timestamp) return value.toDate();
  try {
    final dynamic dynamicVal = value;
    if (dynamicVal.toDate is Function) {
      return dynamicVal.toDate() as DateTime;
    }
  } catch (_) {}
  return null;
}

enum AttendanceStatus {
  present,
  absent,
  half;

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AttendanceStatus.present,
    );
  }
}

class AttendanceEntry {
  final String id;
  final String workerId;
  final DateTime date;
  final AttendanceStatus status;
  final String? siteId;
  final bool hasPendingWrites;

  const AttendanceEntry({
    required this.id,
    required this.workerId,
    required this.date,
    required this.status,
    this.siteId,
    this.hasPendingWrites = false,
  });

  /// One deterministic document per worker/site/day prevents duplicate attendance.
  static String buildId({
    required String siteId,
    required String workerId,
    required DateTime date,
  }) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${siteId}_${workerId}_$year$month$day';
  }

  String get effectiveSiteId {
    if (siteId != null && siteId!.isNotEmpty) {
      return siteId!;
    }
    final parts = id.split('_');
    if (parts.length >= 3) {
      return parts.first;
    }
    return '';
  }

  AttendanceEntry copyWith({
    String? id,
    String? workerId,
    DateTime? date,
    AttendanceStatus? status,
    String? siteId,
    bool? hasPendingWrites,
  }) {
    return AttendanceEntry(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      date: date ?? this.date,
      status: status ?? this.status,
      siteId: siteId ?? this.siteId,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workerId': workerId,
      'date': date.toIso8601String(),
      'status': status.name,
      if (siteId != null) 'siteId': siteId,
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory AttendanceEntry.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return AttendanceEntry(
      id: map['id'] as String? ?? '',
      workerId: map['workerId'] as String? ?? '',
      date: _parseDateTime(map['date']) ?? DateTime.now(),
      status: map['status'] is String
          ? AttendanceStatus.fromString(map['status'] as String)
          : (map['status'] as AttendanceStatus? ?? AttendanceStatus.present),
      siteId: map['siteId'] as String?,
      hasPendingWrites: (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  /// Local calendar dates keep range keys as yyyy-MM-dd strings.
  static String dateKeyFromDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Map<String, dynamic> toFirestore({required String createdBy}) {
    return {
      'workerId': workerId,
      'status': status.name,
      'dateKey': dateKeyFromDate(date),
      'updatedAt': Timestamp.now(),
      'createdBy': createdBy,
    };
  }

  factory AttendanceEntry.fromFirestore(
    String docId,
    String siteId,
    Map<String, dynamic> data, {
    bool hasPendingWrites = false,
  }) {
    DateTime date;
    final dateKey = data['dateKey'] as String?;
    if (dateKey != null && dateKey.length == 10) {
      date = DateTime.tryParse(dateKey) ?? DateTime.now();
    } else {
      date = _parseDateTime(data['updatedAt']) ?? DateTime.now();
    }

    return AttendanceEntry(
      id: docId,
      workerId: data['workerId'] as String? ?? '',
      date: date,
      status: data['status'] is String
          ? AttendanceStatus.fromString(data['status'] as String)
          : AttendanceStatus.present,
      siteId: siteId,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workerId == other.workerId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          status == other.status &&
          siteId == other.siteId &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode => Object.hash(
    id,
    workerId,
    date.year,
    date.month,
    date.day,
    status,
    siteId,
    hasPendingWrites,
  );

  @override
  String toString() =>
      'AttendanceEntry(id: $id, workerId: $workerId, date: $date, status: ${status.name}, siteId: $siteId, hasPendingWrites: $hasPendingWrites)';
}
