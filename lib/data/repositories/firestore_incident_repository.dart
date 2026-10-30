import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/repositories/firestore_site_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:uuid/uuid.dart';

/// Real Firestore-backed [IncidentRepository].
///
/// Incidents are immutable client-created records under
/// `sites/{siteId}/incidents`.
class FirestoreIncidentRepository implements IncidentRepository {
  FirestoreIncidentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this._defaultLimit = 200,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final int _defaultLimit;

  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  CollectionReference<Map<String, dynamic>> _incidentsCol(String siteId) =>
      _db.collection('sites').doc(siteId).collection('incidents');

  String get _currentUid => _auth.currentUser?.uid ?? '';

  @override
  Stream<List<Incident>> watchIncidents({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  }) {
    final range = _effectiveRange(startDate, endDate);
    final from = range.$1 == null ? null : _startOfDay(range.$1!);
    final through = range.$2 == null ? null : _endOfDay(range.$2!);
    if (siteId != null && siteId.isNotEmpty) {
      return _watchSiteIncidents(
        siteId: siteId,
        startDate: from,
        endDate: through,
        severity: severity,
      );
    }
    return combineSiteStreams(
      watchAllSites(_db),
      (id) => _watchSiteIncidents(
        siteId: id,
        startDate: from,
        endDate: through,
        severity: severity,
      ),
    );
  }

  Stream<List<Incident>> _watchSiteIncidents({
    required String siteId,
    required DateTime? startDate,
    required DateTime? endDate,
    Severity? severity,
  }) {
    Query<Map<String, dynamic>> query = _incidentsCol(siteId);
    if (startDate != null) {
      query = query.where(
        'occurredAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'occurredAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }
    query = query.orderBy('occurredAt', descending: true).limit(_defaultLimit);

    return query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                final data = doc.data();
                return Incident(
                  id: doc.id,
                  severity: Severity.fromString(
                    data['severity'] as String? ?? '',
                  ),
                  description: data['description'] as String? ?? '',
                  occurredAt:
                      (data['occurredAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                  siteId: siteId,
                  hasPendingWrites: doc.metadata.hasPendingWrites,
                );
              })
              .where(
                (incident) => severity == null || incident.severity == severity,
              )
              .toList(),
        );
  }

  @override
  String reportIncident(Incident incident) {
    final id = incident.id.isEmpty ? const Uuid().v4() : incident.id;
    final siteId = incident.siteId;
    if (siteId == null || siteId.isEmpty) {
      _reportInputFailure(
        'reportIncident',
        'Incident must have a valid siteId',
        id,
      );
      return id;
    }
    if (incident.description.trim().length < 10) {
      _reportInputFailure(
        'reportIncident',
        'Incident description must be at least 10 characters',
        id,
      );
      return id;
    }

    final uid = _currentUid;
    if (uid.isEmpty) {
      _reportInputFailure(
        'reportIncident',
        'A signed-in user is required to report an incident',
        id,
      );
      return id;
    }

    final batch = _db.batch();
    batch.set(_incidentsCol(siteId).doc(id), {
      'severity': incident.severity.name,
      'description': incident.description,
      'occurredAt': Timestamp.fromDate(incident.occurredAt),
      'createdBy': uid,
    });
    batch.set(_db.collection('sites').doc(siteId), {
      'lastEntryAt': Timestamp.now(),
    }, SetOptions(merge: true));
    batch.commit().then(
      (_) {},
      onError: (Object error, StackTrace stackTrace) =>
          _reportWriteFailure('reportIncident', id, error, stackTrace),
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

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);

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
