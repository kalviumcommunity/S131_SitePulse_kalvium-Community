import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/repositories/write_failure_sink.dart';

abstract class SyncStatusRepository {
  Stream<List<WriteFailure>> get writeFailures;
  void clearWriteFailures();
  Stream<int> get pendingCount;
  Stream<bool> get allSynced;
}

class FirestoreSyncStatusRepository implements SyncStatusRepository {
  FirestoreSyncStatusRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    WriteFailureSink? failureSink,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _failureSink = failureSink ?? writeFailureSink;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WriteFailureSink _failureSink;

  @override
  Stream<List<WriteFailure>> get writeFailures => _failureSink.failures;

  @override
  void clearWriteFailures() => _failureSink.clear();

  @override
  Stream<int> get pendingCount => _auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<int>.value(0);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .asyncExpand((profile) {
          final data = profile.data();
          final siteId = data?['siteId'] as String?;
          if (!profile.exists ||
              data?['role'] != 'supervisor' ||
              siteId == null ||
              siteId.isEmpty) {
            return Stream<int>.value(0);
          }

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final firstDay = today.subtract(const Duration(days: 6));
          final startKey = _dateKey(firstDay);
          final endKey = _dateKey(today);
          final site = _firestore.collection('sites').doc(siteId);
          return _combinePendingCounts([
            site
                .collection('attendance')
                .where('createdBy', isEqualTo: user.uid)
                .where('dateKey', isGreaterThanOrEqualTo: startKey)
                .where('dateKey', isLessThanOrEqualTo: endKey)
                .snapshots(includeMetadataChanges: true),
            site
                .collection('materialLogs')
                .where('createdBy', isEqualTo: user.uid)
                .where('dateKey', isGreaterThanOrEqualTo: startKey)
                .where('dateKey', isLessThanOrEqualTo: endKey)
                .snapshots(includeMetadataChanges: true),
            site
                .collection('incidents')
                .where('createdBy', isEqualTo: user.uid)
                .where(
                  'occurredAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay),
                )
                .where(
                  'occurredAt',
                  isLessThan: Timestamp.fromDate(
                    today.add(const Duration(days: 1)),
                  ),
                )
                .snapshots(includeMetadataChanges: true),
          ]);
        });
  });

  @override
  Stream<bool> get allSynced {
    late final StreamController<bool> controller;
    StreamSubscription<int>? pendingSubscription;
    StreamSubscription<void>? syncSubscription;
    int? currentPendingCount;
    var receivedSyncEvent = false;

    void emitIfReady() {
      if (currentPendingCount != null && receivedSyncEvent) {
        controller.add(currentPendingCount == 0);
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        pendingSubscription = pendingCount.listen((pendingItems) {
          currentPendingCount = pendingItems;
          emitIfReady();
        }, onError: controller.addError);
        syncSubscription = _firestore.snapshotsInSync().listen((_) {
          receivedSyncEvent = true;
          emitIfReady();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await Future.wait([
          if (pendingSubscription != null) pendingSubscription!.cancel(),
          if (syncSubscription != null) syncSubscription!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Stream<int> _combinePendingCounts(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
  ) {
    late final StreamController<int> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final counts = List<int?>.filled(streams.length, null);

    controller = StreamController<int>(
      onListen: () {
        for (var index = 0; index < streams.length; index++) {
          subscriptions.add(
            streams[index].listen((snapshot) {
              counts[index] = snapshot.docs
                  .where((document) => document.metadata.hasPendingWrites)
                  .length;
              if (counts.every((itemTotal) => itemTotal != null)) {
                controller.add(
                  counts.cast<int>().fold(
                    0,
                    (runningTotal, value) => runningTotal + value,
                  ),
                );
              }
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        await Future.wait(
          subscriptions.map((subscription) => subscription.cancel()),
        );
        subscriptions.clear();
      },
    );
    return controller.stream;
  }
}
