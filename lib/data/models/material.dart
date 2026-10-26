class Material {
  final String id;
  final String name;
  final String unit;
  final double openingStock;
  final double currentStock;
  final double lowStockThreshold;
  final bool hasPendingWrites;

  const Material({
    required this.id,
    required this.name,
    required this.unit,
    required this.openingStock,
    required this.currentStock,
    required this.lowStockThreshold,
    this.hasPendingWrites = false,
  });

  Material copyWith({
    String? id,
    String? name,
    String? unit,
    double? openingStock,
    double? currentStock,
    double? lowStockThreshold,
    bool? hasPendingWrites,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      openingStock: openingStock ?? this.openingStock,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'openingStock': openingStock,
      'currentStock': currentStock,
      'lowStockThreshold': lowStockThreshold,
      'hasPendingWrites': hasPendingWrites,
    };
  }

  factory Material.fromMap(
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    return Material(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      openingStock: (map['openingStock'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold:
          (map['lowStockThreshold'] as num?)?.toDouble() ?? 0.0,
      hasPendingWrites:
          (map['hasPendingWrites'] as bool?) ?? hasPendingWrites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Material &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          unit == other.unit &&
          openingStock == other.openingStock &&
          currentStock == other.currentStock &&
          lowStockThreshold == other.lowStockThreshold &&
          hasPendingWrites == other.hasPendingWrites;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        unit,
        openingStock,
        currentStock,
        lowStockThreshold,
        hasPendingWrites,
      );

  @override
  String toString() =>
      'Material(id: $id, name: $name, unit: $unit, openingStock: $openingStock, currentStock: $currentStock, lowStockThreshold: $lowStockThreshold, hasPendingWrites: $hasPendingWrites)';
}
