import 'package:site_pulse/data/models/material.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class MaterialRepository {
  /// Watch all materials
  Stream<List<Material>> watchMaterials();

  /// Watch a single material
  Stream<Material?> watchMaterial(String id);

  /// Watch material usage logs with optional material and date-range filters
  Stream<List<MaterialLog>> watchMaterialLogs({
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Fire-and-forget write: returns material id immediately
  String saveMaterial(Material material);

  /// One operation that logs usage and decrements currentStock.
  /// Fire-and-forget: returns log id immediately and reports failures to errorStream.
  String logUsage({
    required String materialId,
    required double qtyUsed,
    DateTime? date,
    String? logId,
  });

  Stream<RepositoryError> get errorStream;
}
