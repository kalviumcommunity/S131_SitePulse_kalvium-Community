class Worker {
  final String id;
  final String name;
  final String trade;
  final String workerCode;
  final bool active;
  final String? siteId;
  final bool hasPendingWrites;

  const Worker({
    required this.id,
    required this.name,
    required this.trade,
    required this.workerCode,
    required this.active,
    this.siteId,
    this.hasPendingWrites = false,
  });

  Worker copyWith({
    String? id,
    String? name,
    String? trade,
    String? workerCode,
    bool? active,
    String? siteId,
    bool? hasPendingWrites,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      trade: trade ?? this.trade,
      workerCode: workerCode ?? this.workerCode,
      active: active ?? this.active,
      siteId: siteId ?? this.siteId,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'trade': trade,
      'workerCode': workerCode,
      'active': active,
      if (siteId != null) 'siteId': siteId,
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory Worker.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return Worker(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      trade: map['trade'] as String? ?? '',
      workerCode: map['workerCode'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      siteId: map['siteId'] as String?,
      hasPendingWrites:
          (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  /// Firestore document data (excludes id, siteId, hasPendingWrites).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'trade': trade,
      'workerCode': workerCode,
      'active': active,
    };
  }

  /// Construct from a Firestore document snapshot.
  factory Worker.fromFirestore(
    String docId,
    String siteId,
    Map<String, dynamic> data, {
    bool hasPendingWrites = false,
  }) {
    return Worker(
      id: docId,
      name: data['name'] as String? ?? '',
      trade: data['trade'] as String? ?? '',
      workerCode: data['workerCode'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      siteId: siteId,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Worker &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          trade == other.trade &&
          workerCode == other.workerCode &&
          active == other.active &&
          siteId == other.siteId &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode =>
      Object.hash(id, name, trade, workerCode, active, siteId, hasPendingWrites);

  @override
  String toString() =>
      'Worker(id: $id, name: $name, trade: $trade, workerCode: $workerCode, active: $active, siteId: $siteId, hasPendingWrites: $hasPendingWrites)';
}
