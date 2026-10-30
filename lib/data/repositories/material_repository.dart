import 'package:site_pulse/data/models/material.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class MaterialRepository {
  Stream<List<Material>> watchMaterials({String? siteId});

  Stream<Material?> watchMaterial(String id, {String? siteId});

  Stream<List<MaterialLog>> watchMaterialLogs({
    String? siteId,
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns immediately so callers never wait for offline writes.
  String logUsage({
    required String materialId,
    required double qtyUsed,
    String? siteId,
    DateTime? date,
    String? logId,
  });

  Stream<RepositoryError> get errorStream;
}
