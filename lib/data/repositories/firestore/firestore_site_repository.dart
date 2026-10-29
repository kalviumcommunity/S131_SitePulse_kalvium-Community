import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';

/// Real Firestore-backed [SiteRepository].
///
/// Read pattern: `snapshots(includeMetadataChanges: true)` so we can surface
/// `hasPendingWrites` to the UI via [Site.hasPendingWrites].
///
/// Write pattern: fire-and-forget with `batch.commit()` — never awaited by
/// the caller.  Write failures are pushed onto [errorStream].
class FirestoreSiteRepository implements SiteRepository {
  FirestoreSiteRepository({
    FirebaseFirestore? firestore,
    this._watchSitesLimit = 50,
  })  : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final int _watchSitesLimit;

  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  CollectionReference<Map<String, dynamic>> get _sitesCol =>
      _db.collection('sites');

  // ── Reads ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Site>> watchSites() {
    return _sitesCol
        .limit(_watchSitesLimit)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map((doc) {
              return Site.fromFirestore(
                doc.id,
                doc.data(),
                hasPendingWrites: doc.metadata.hasPendingWrites,
              );
            }).toList());
  }

  @override
  Stream<Site?> watchSite(String siteId) {
    return _sitesCol
        .doc(siteId)
        .snapshots(includeMetadataChanges: true)
        .map((doc) {
      if (!doc.exists) return null;
      return Site.fromFirestore(
        doc.id,
        doc.data()!,
        hasPendingWrites: doc.metadata.hasPendingWrites,
      );
    });
  }

  // ── Error stream ───────────────────────────────────────────────────────

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _errorController.close();
  }
}
