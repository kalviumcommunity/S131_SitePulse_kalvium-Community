import 'dart:async';

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
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/data/repositories/firestore/firestore.dart';

/// Set to `false` to switch from in-memory fakes to real Firestore repositories.
const bool useFakes = true;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = FakeAuthRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'users',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  if (useFakes) {
    final repository = FakeSiteRepository();
    _forwardRepositoryFailures(
      errorStream: repository.errorStream,
      collection: 'sites',
      onDispose: ref.onDispose,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirestoreSiteRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'sites',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  if (useFakes) {
    final repository = FakeWorkerRepository();
    _forwardRepositoryFailures(
      errorStream: repository.errorStream,
      collection: 'workers',
      onDispose: ref.onDispose,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirestoreWorkerRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'workers',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  if (useFakes) {
    final repository = FakeAttendanceRepository();
    _forwardRepositoryFailures(
      errorStream: repository.errorStream,
      collection: 'attendance',
      onDispose: ref.onDispose,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirestoreAttendanceRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'attendance',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  if (useFakes) {
    final repository = FakeMaterialRepository();
    _forwardRepositoryFailures(
      errorStream: repository.errorStream,
      collection: 'materialLogs',
      onDispose: ref.onDispose,
      collectionForError: (error) =>
          error.operation == 'saveMaterial' ? 'materials' : 'materialLogs',
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirestoreMaterialRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'materialLogs',
    onDispose: ref.onDispose,
    collectionForError: (error) =>
        error.operation == 'saveMaterial' ? 'materials' : 'materialLogs',
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  if (useFakes) {
    final repository = FakeIncidentRepository();
    _forwardRepositoryFailures(
      errorStream: repository.errorStream,
      collection: 'incidents',
      onDispose: ref.onDispose,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  final repository = FirestoreIncidentRepository();
  _forwardRepositoryFailures(
    errorStream: repository.errorStream,
    collection: 'incidents',
    onDispose: ref.onDispose,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  if (useFakes) {
    final repository = FakeSyncStatusRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }
  return FirestoreSyncStatusRepository(failureSink: writeFailureSink);
});

void _forwardRepositoryFailures({
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
