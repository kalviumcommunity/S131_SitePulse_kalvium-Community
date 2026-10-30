import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/sync_status_repository.dart';
import 'package:site_pulse/data/repositories/write_failure_sink.dart';
import 'package:site_pulse/data/repositories/firestore_auth_repository.dart';
import 'package:site_pulse/data/repositories/firestore_site_repository.dart';
import 'package:site_pulse/data/repositories/firestore_worker_repository.dart';
import 'package:site_pulse/data/repositories/firestore_attendance_repository.dart';
import 'package:site_pulse/data/repositories/firestore_material_repository.dart';
import 'package:site_pulse/data/repositories/firestore_incident_repository.dart';
import 'package:site_pulse/data/repositories/firestore_sync_status_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirestoreAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  final repository = FirestoreSiteRepository();
  forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'sites',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  final repository = FirestoreWorkerRepository();
  forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'workers',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final repository = FirestoreAttendanceRepository();
  forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'attendance',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final repository = FirestoreMaterialRepository();
  forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'materialLogs',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  final repository = FirestoreIncidentRepository();
  forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'incidents',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  return FirestoreSyncStatusRepository(failureSink: writeFailureSink);
});

@visibleForTesting
void forwardRepositoryFailures({
  required Stream<RepositoryError> errorStream,
  required String collection,
  required void Function(void Function()) onDispose,
  String Function(RepositoryError error)? collectionForError,
}) {
  final subscription = errorStream.listen(
    (error) => writeFailureSink.report(
      collectionForError?.call(error) ?? collection,
      error,
    ),
  );
  onDispose(() => unawaited(subscription.cancel()));
}
