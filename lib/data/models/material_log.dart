DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    final dynamic dynamicVal = value;
    if (dynamicVal.toDate is Function) {
      return dynamicVal.toDate() as DateTime;
    }
  } catch (_) {}
  return null;
}

class MaterialLog {
  final String id;
  final String materialId;
  final double qtyUsed;
  final double remainingAfter;
  final DateTime date;
  final bool hasPendingWrites;

  const MaterialLog({
    required this.id,
    required this.materialId,
    required this.qtyUsed,
    required this.remainingAfter,
    required this.date,
    this.hasPendingWrites = false,
  });

  MaterialLog copyWith({
    String? id,
    String? materialId,
    double? qtyUsed,
    double? remainingAfter,
    DateTime? date,
    bool? hasPendingWrites,
  }) {
    return MaterialLog(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      qtyUsed: qtyUsed ?? this.qtyUsed,
      remainingAfter: remainingAfter ?? this.remainingAfter,
      date: date ?? this.date,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'materialId': materialId,
      'qtyUsed': qtyUsed,
      'remainingAfter': remainingAfter,
      'date': date.toIso8601String(),
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory MaterialLog.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return MaterialLog(
      id: map['id'] as String? ?? '',
      materialId: map['materialId'] as String? ?? '',
      qtyUsed: (map['qtyUsed'] as num?)?.toDouble() ?? 0.0,
      remainingAfter: (map['remainingAfter'] as num?)?.toDouble() ?? 0.0,
      date: _parseDateTime(map['date']) ?? DateTime.now(),
      hasPendingWrites:
          (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          qtyUsed == other.qtyUsed &&
          remainingAfter == other.remainingAfter &&
          date.toIso8601String() == other.date.toIso8601String() &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode => Object.hash(
        id,
        materialId,
        qtyUsed,
        remainingAfter,
        date.toIso8601String(),
        hasPendingWrites,
      );

  @override
  String toString() =>
      'MaterialLog(id: $id, materialId: $materialId, qtyUsed: $qtyUsed, remainingAfter: $remainingAfter, date: $date, hasPendingWrites: $hasPendingWrites)';
}
