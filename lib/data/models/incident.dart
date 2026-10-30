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

enum Severity {
  minor,
  moderate,
  high,
  critical;

  static Severity fromString(String value) {
    return Severity.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Severity.minor,
    );
  }
}

class Incident {
  final String id;
  final Severity severity;
  final String description;
  final DateTime occurredAt;
  final String? siteId;
  final bool hasPendingWrites;

  const Incident({
    required this.id,
    required this.severity,
    required this.description,
    required this.occurredAt,
    this.siteId,
    this.hasPendingWrites = false,
  });

  Incident copyWith({
    String? id,
    Severity? severity,
    String? description,
    DateTime? occurredAt,
    String? siteId,
    bool? hasPendingWrites,
  }) {
    return Incident(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      siteId: siteId ?? this.siteId,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'severity': severity.name,
      'description': description,
      'occurredAt': occurredAt.toIso8601String(),
      if (siteId != null) 'siteId': siteId,
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory Incident.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return Incident(
      id: map['id'] as String? ?? '',
      severity: map['severity'] is String
          ? Severity.fromString(map['severity'] as String)
          : (map['severity'] as Severity? ?? Severity.minor),
      description: map['description'] as String? ?? '',
      occurredAt: _parseDateTime(map['occurredAt']) ?? DateTime.now(),
      siteId: map['siteId'] as String?,
      hasPendingWrites: (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Incident &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          severity == other.severity &&
          description == other.description &&
          occurredAt.toIso8601String() == other.occurredAt.toIso8601String() &&
          siteId == other.siteId &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode => Object.hash(
    id,
    severity,
    description,
    occurredAt.toIso8601String(),
    siteId,
    hasPendingWrites,
  );

  @override
  String toString() =>
      'Incident(id: $id, severity: ${severity.name}, description: $description, occurredAt: $occurredAt, siteId: $siteId, hasPendingWrites: $hasPendingWrites)';
}
