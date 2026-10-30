import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:site_pulse/data/repositories/firestore_site_repository.dart';

/// Real Firestore-backed [WorkerRepository].
///
/// Workers live at `sites/{siteId}/workers/{workerId}`.
/// Remove = soft-delete (set `active` to `false`).
class FirestoreWorkerRepository implements WorkerRepository {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  FirestoreWorkerRepository({
    FirebaseFirestore? firestore,
    this._defaultLimit = 200,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final int _defaultLimit;

  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  CollectionReference<Map<String, dynamic>> _workersCol(String siteId) =>
      _db.collection('sites').doc(siteId).collection('workers');

  // ── Reads ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly}) {
    Query<Map<String, dynamic>> query = _workersCol(siteId);
    if (activeOnly != false) {
      query = query.where('active', isEqualTo: true);
    }
    query = query.limit(_defaultLimit);

    return query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => snap.docs.map((doc) {
            return Worker.fromFirestore(
              doc.id,
              siteId,
              doc.data(),
              hasPendingWrites: doc.metadata.hasPendingWrites,
            );
          }).toList(),
        );
  }

  @override
  Stream<List<Worker>> watchAllWorkers() {
    return combineSiteStreams(
      watchAllSites(_db),
      (siteId) => watchWorkers(siteId),
    );
  }

  // ── Writes (fire-and-forget) ───────────────────────────────────────────

  @override
  String saveWorker(String siteId, Worker worker) {
    final id = _uuidPattern.hasMatch(worker.id) ? worker.id : const Uuid().v4();

    final batch = _db.batch();
    batch.set(
      _workersCol(siteId).doc(id),
      worker.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(_db.collection('sites').doc(siteId), {
      'lastEntryAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.commit().then(
      (_) {},
      onError: (Object e, StackTrace st) =>
          _reportWriteFailure('saveWorker', id, e, st),
    );
    return id;
  }

  @override
  String toggleWorkerActive(String siteId, String workerId, bool active) {
    final batch = _db.batch();
    batch.update(_workersCol(siteId).doc(workerId), {'active': active});
    batch.set(_db.collection('sites').doc(siteId), {
      'lastEntryAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.commit().then(
      (_) {},
      onError: (Object e, StackTrace st) =>
          _reportWriteFailure('toggleWorkerActive', workerId, e, st),
    );
    return workerId;
  }

  // ── Error stream ───────────────────────────────────────────────────────

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

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
