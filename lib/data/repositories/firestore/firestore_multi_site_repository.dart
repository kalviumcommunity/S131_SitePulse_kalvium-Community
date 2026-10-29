import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:site_pulse/data/models/site.dart';

Stream<List<Site>> watchAllSites(FirebaseFirestore firestore) {
  return firestore
      .collection('sites')
      .limit(50)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => Site.fromFirestore(
                doc.id,
                doc.data(),
                hasPendingWrites: doc.metadata.hasPendingWrites,
              ),
            )
            .toList(),
      );
}

Stream<List<T>> combineSiteStreams<T>(
  Stream<List<Site>> sites,
  Stream<List<T>> Function(String siteId) watchSite,
) {
  late final StreamController<List<T>> controller;
  StreamSubscription<List<Site>>? sitesSubscription;
  final subscriptions = <String, StreamSubscription<List<T>>>{};
  final latestBySite = <String, List<T>>{};
  var siteOrder = <String>[];
  var cancelled = false;

  void emit() {
    if (cancelled || controller.isClosed) return;
    controller.add([for (final siteId in siteOrder) ...?latestBySite[siteId]]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      sitesSubscription = sites.listen((siteList) {
        if (cancelled) return;
        siteOrder = siteList.map((site) => site.id).toList();
        final currentIds = siteOrder.toSet();

        for (final siteId in subscriptions.keys.toList()) {
          if (!currentIds.contains(siteId)) {
            unawaited(subscriptions.remove(siteId)!.cancel());
            latestBySite.remove(siteId);
          }
        }

        for (final siteId in siteOrder) {
          if (subscriptions.containsKey(siteId)) continue;
          subscriptions[siteId] = watchSite(siteId).listen((items) {
            if (cancelled || !siteOrder.contains(siteId)) return;
            latestBySite[siteId] = items;
            emit();
          }, onError: controller.addError);
        }
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      cancelled = true;
      final activeSubscriptions = subscriptions.values.toList();
      subscriptions.clear();
      await Future.wait([
        if (sitesSubscription != null) sitesSubscription!.cancel(),
        for (final subscription in activeSubscriptions) subscription.cancel(),
      ]);
    },
  );

  return controller.stream;
}
