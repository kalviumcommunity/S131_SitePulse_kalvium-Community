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

class Site {
  final String id;
  final String name;
  final DateTime? lastEntryAt;
  final bool hasPendingWrites;

  const Site({
    required this.id,
    required this.name,
    this.lastEntryAt,
    this.hasPendingWrites = false,
  });

  Site copyWith({
    String? id,
    String? name,
    DateTime? lastEntryAt,
    bool? hasPendingWrites,
  }) {
    return Site(
      id: id ?? this.id,
      name: name ?? this.name,
      lastEntryAt: lastEntryAt ?? this.lastEntryAt,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (lastEntryAt != null) 'lastEntryAt': lastEntryAt!.toIso8601String(),
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory Site.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return Site(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lastEntryAt: _parseDateTime(map['lastEntryAt']),
      hasPendingWrites:
          (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Site &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          lastEntryAt == other.lastEntryAt &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode => Object.hash(id, name, lastEntryAt, hasPendingWrites);

  @override
  String toString() =>
      'Site(id: $id, name: $name, lastEntryAt: $lastEntryAt, hasPendingWrites: $hasPendingWrites)';
}
