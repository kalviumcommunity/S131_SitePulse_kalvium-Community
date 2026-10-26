import 'dart:async';
import 'package:site_pulse/data/models/material.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

class FakeMaterialRepository implements MaterialRepository {
  static List<Material> get defaultMaterials => [
        // One below threshold: currentStock 15 <= lowStockThreshold 25
        const Material(
          id: 'mat-1',
          name: 'Portland Cement (50kg)',
          unit: 'bags',
          openingStock: 100.0,
          currentStock: 15.0,
          lowStockThreshold: 25.0,
        ),
        const Material(
          id: 'mat-2',
          name: 'Coarse River Sand',
          unit: 'tonnes',
          openingStock: 60.0,
          currentStock: 45.0,
          lowStockThreshold: 10.0,
        ),
        const Material(
          id: 'mat-3',
          name: 'TMT Steel Rebar (12mm)',
          unit: 'tonnes',
          openingStock: 40.0,
          currentStock: 28.0,
          lowStockThreshold: 12.0,
        ),
        const Material(
          id: 'mat-4',
          name: 'Structural Concrete M25',
          unit: 'm3',
          openingStock: 80.0,
          currentStock: 50.0,
          lowStockThreshold: 20.0,
        ),
      ];

  final Map<String, Material> _materials = {};
  final List<MaterialLog> _logs = [];
  final StreamController<void> _materialChangeController =
      StreamController<void>.broadcast();
  final StreamController<void> _logChangeController =
      StreamController<void>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeMaterialRepository({
    List<Material>? initialMaterials,
    List<MaterialLog>? initialLogs,
  }) {
    final list = initialMaterials ?? defaultMaterials;
    for (final m in list) {
      _materials[m.id] = m;
    }
    if (initialLogs != null) {
      _logs.addAll(initialLogs);
    }
  }

  @override
  Stream<List<Material>> watchMaterials() async* {
    yield _materials.values.toList();
    yield* _materialChangeController.stream.map((_) => _materials.values.toList());
  }

  @override
  Stream<Material?> watchMaterial(String id) async* {
    yield _materials[id];
    yield* _materialChangeController.stream.map((_) => _materials[id]);
  }

  @override
  Stream<List<MaterialLog>> watchMaterialLogs({
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  }) async* {
    yield _filterLogs(materialId, startDate, endDate);
    yield* _logChangeController.stream.map(
      (_) => _filterLogs(materialId, startDate, endDate),
    );
  }

  List<MaterialLog> _filterLogs(
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return _logs.where((log) {
      if (materialId != null && log.materialId != materialId) return false;
      if (startDate != null && log.date.isBefore(startDate)) return false;
      if (endDate != null && log.date.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  @override
  String saveMaterial(Material material) {
    if (material.id.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'saveMaterial',
          message: 'Material id cannot be empty',
        ),
      );
      return '';
    }
    _materials[material.id] = material;
    _materialChangeController.add(null);
    return material.id;
  }

  @override
  String logUsage({
    required String materialId,
    required double qtyUsed,
    DateTime? date,
    String? logId,
  }) {
    final effectiveLogId = logId ?? 'log-${DateTime.now().microsecondsSinceEpoch}';
    final existing = _materials[materialId];
    if (existing == null) {
      _errorController.add(
        RepositoryError(
          operation: 'logUsage',
          message: 'Material with id $materialId does not exist',
          documentId: effectiveLogId,
        ),
      );
      return effectiveLogId;
    }

    if (qtyUsed <= 0) {
      _errorController.add(
        RepositoryError(
          operation: 'logUsage',
          message: 'Quantity used must be greater than zero',
          documentId: effectiveLogId,
        ),
      );
      return effectiveLogId;
    }

    final newRemaining = existing.currentStock - qtyUsed;
    final log = MaterialLog(
      id: effectiveLogId,
      materialId: materialId,
      qtyUsed: qtyUsed,
      remainingAfter: newRemaining,
      date: date ?? DateTime.now(),
    );

    _materials[materialId] = existing.copyWith(currentStock: newRemaining);
    _logs.add(log);

    _materialChangeController.add(null);
    _logChangeController.add(null);

    return effectiveLogId;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _materialChangeController.close();
    _logChangeController.close();
    _errorController.close();
  }
}
