import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:site_pulse/data/models/material.dart';
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/repositories/firestore/firestore_multi_site_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:uuid/uuid.dart';

/// Real Firestore-backed [MaterialRepository].
///
/// Material data is stored below `sites/{siteId}/materials` and usage logs
/// below `sites/{siteId}/materialLogs`.
class FirestoreMaterialRepository implements MaterialRepository {
  FirestoreMaterialRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this._defaultLimit = 500,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final int _defaultLimit;

  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();
  final Map<String, Map<String, _KnownMaterial>> _knownMaterials = {};

  CollectionReference<Map<String, dynamic>> _materialsCol(String siteId) =>
      _db.collection('sites').doc(siteId).collection('materials');

  CollectionReference<Map<String, dynamic>> _logsCol(String siteId) =>
      _db.collection('sites').doc(siteId).collection('materialLogs');

  String get _currentUid => _auth.currentUser?.uid ?? '';

  @override
  Stream<List<Material>> watchMaterials() {
    return combineSiteStreams(watchAllSites(_db), _watchSiteMaterials);
  }

  Stream<List<Material>> _watchSiteMaterials(String siteId) {
    return _materialsCol(siteId)
        .limit(_defaultLimit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          for (final materialsBySite in _knownMaterials.values) {
            materialsBySite.remove(siteId);
          }
          _knownMaterials.removeWhere(
            (_, materialsBySite) => materialsBySite.isEmpty,
          );

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final material = Material(
              id: doc.id,
              name: data['name'] as String? ?? '',
              unit: data['unit'] as String? ?? '',
              openingStock: (data['openingStock'] as num?)?.toDouble() ?? 0,
              currentStock: (data['currentStock'] as num?)?.toDouble() ?? 0,
              lowStockThreshold:
                  (data['lowStockThreshold'] as num?)?.toDouble() ?? 0,
              hasPendingWrites: doc.metadata.hasPendingWrites,
            );
            _knownMaterials.putIfAbsent(doc.id, () => {})[siteId] =
                _KnownMaterial(material: material, siteId: siteId);
            return material;
          }).toList();
        });
  }

  @override
  Stream<Material?> watchMaterial(String id) {
    return watchMaterials().map((materials) {
      for (final material in materials) {
        if (material.id == id) return material;
      }
      return null;
    });
  }

  @override
  Stream<List<MaterialLog>> watchMaterialLogs({
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final range = _effectiveRange(startDate, endDate);
    return combineSiteStreams(
      watchAllSites(_db),
      (siteId) => _watchSiteLogs(
        siteId: siteId,
        materialId: materialId,
        startDate: range.$1,
        endDate: range.$2,
      ),
    );
  }

  Stream<List<MaterialLog>> _watchSiteLogs({
    required String siteId,
    required DateTime? startDate,
    required DateTime? endDate,
    String? materialId,
  }) {
    Query<Map<String, dynamic>> query = _logsCol(siteId);
    if (materialId != null) {
      query = query.where('materialId', isEqualTo: materialId);
    }
    if (startDate != null) {
      query = query.where(
        'dateKey',
        isGreaterThanOrEqualTo: _dateKeyFromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'dateKey',
        isLessThanOrEqualTo: _dateKeyFromDate(endDate),
      );
    }

    return query
        .limit(_defaultLimit)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final dateKey = data['dateKey'] as String?;
            final date = dateKey == null
                ? (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
                : DateTime.tryParse(dateKey) ?? DateTime.now();
            return MaterialLog(
              id: doc.id,
              materialId: data['materialId'] as String? ?? '',
              qtyUsed: (data['qtyUsed'] as num?)?.toDouble() ?? 0,
              remainingAfter: (data['remainingAfter'] as num?)?.toDouble() ?? 0,
              date: date,
              hasPendingWrites: doc.metadata.hasPendingWrites,
            );
          }).toList(),
        );
  }

  @override
  String saveMaterial(Material material) {
    _errorController.add(
      RepositoryError(
        operation: 'saveMaterial',
        message: 'Materials are managed outside the client application',
        documentId: material.id,
      ),
    );
    return material.id;
  }

  @override
  String logUsage({
    required String materialId,
    required double qtyUsed,
    DateTime? date,
    String? logId,
  }) {
    final id = logId ?? const Uuid().v4();
    if (id.isEmpty) {
      _reportInputFailure('logUsage', 'Log id cannot be empty', id);
      return id;
    }
    if (!qtyUsed.isFinite || qtyUsed <= 0) {
      _reportInputFailure(
        'logUsage',
        'Quantity used must be greater than zero',
        id,
      );
      return id;
    }

    final candidates = _knownMaterials[materialId]?.values.toList() ?? [];
    if (candidates.length != 1) {
      _reportInputFailure(
        'logUsage',
        candidates.isEmpty
            ? 'Material $materialId is not available in the local cache'
            : 'Material $materialId is ambiguous across sites',
        id,
      );
      return id;
    }

    final known = candidates.single;
    if (qtyUsed > known.material.currentStock) {
      _reportInputFailure(
        'logUsage',
        'Quantity used cannot exceed the known current stock',
        id,
      );
      return id;
    }

    final uid = _currentUid;
    if (uid.isEmpty) {
      _reportInputFailure(
        'logUsage',
        'A signed-in user is required to log material usage',
        id,
      );
      return id;
    }

    final effectiveDate = date ?? DateTime.now();
    final remainingAfter = known.material.currentStock - qtyUsed;
    final batch = _db.batch();
    batch.set(_logsCol(known.siteId).doc(id), {
      'materialId': materialId,
      'materialName': known.material.name,
      'qtyUsed': qtyUsed,
      'remainingAfter': remainingAfter,
      'dateKey': _dateKeyFromDate(effectiveDate),
      'createdAt': Timestamp.fromDate(effectiveDate),
      'createdBy': uid,
    });
    batch.update(_materialsCol(known.siteId).doc(materialId), {
      'currentStock': FieldValue.increment(-qtyUsed),
    });
    batch.set(_db.collection('sites').doc(known.siteId), {
      'lastEntryAt': Timestamp.now(),
    }, SetOptions(merge: true));

    _knownMaterials[materialId]![known.siteId] = _KnownMaterial(
      material: known.material.copyWith(currentStock: remainingAfter),
      siteId: known.siteId,
    );
    batch.commit().then(
      (_) {},
      onError: (Object error, StackTrace stackTrace) =>
          _reportWriteFailure('logUsage', id, error, stackTrace),
    );
    return id;
  }

  (DateTime?, DateTime?) _effectiveRange(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate != null || endDate != null) {
      return (startDate, endDate);
    }
    final now = DateTime.now();
    return (now.subtract(const Duration(days: 30)), now);
  }

  String _dateKeyFromDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void _reportInputFailure(String operation, String message, String id) {
    _errorController.add(
      RepositoryError(
        operation: operation,
        message: message,
        documentId: id.isEmpty ? null : id,
      ),
    );
  }

  void _reportWriteFailure(
    String operation,
    String docId,
    Object error,
    StackTrace stackTrace,
  ) {
    _errorController.add(
      RepositoryError(
        operation: operation,
        message: error.toString(),
        error: error,
        stackTrace: stackTrace,
        documentId: docId,
      ),
    );
  }

  void dispose() {
    _errorController.close();
  }
}

class _KnownMaterial {
  const _KnownMaterial({required this.material, required this.siteId});

  final Material material;
  final String siteId;
}
