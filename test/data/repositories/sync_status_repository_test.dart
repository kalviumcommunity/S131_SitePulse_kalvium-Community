import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/providers.dart';
import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';
import 'package:site_pulse/data/repositories/repositories.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  group('WriteFailureSink', () {
    test('maps repository errors to identifiable write failures', () async {
      final sink = WriteFailureSink();
      sink.report(
        'attendance',
        const RepositoryError(
          operation: 'recordAttendance',
          message: 'Firestore write rejected',
          documentId: 'site-1_worker-1_20261028',
        ),
      );

      final failures = await sink.failures.first;
      expect(failures, hasLength(1));
      expect(
        failures.single,
        isA<WriteFailure>()
            .having((failure) => failure.collection, 'collection', 'attendance')
            .having(
              (failure) => failure.documentId,
              'documentId',
              'site-1_worker-1_20261028',
            )
            .having(
              (failure) => failure.message,
              'message',
              'Firestore write rejected',
            )
            .having((failure) => failure.time, 'time', isA<DateTime>()),
      );
    });
  });

  group('FakeSyncStatusRepository', () {
    test('exposes configurable counts and clears write failures', () async {
      final sink = WriteFailureSink();
      final repository = FakeSyncStatusRepository(
        pendingCount: 2,
        allSynced: false,
        failureSink: sink,
      );
      addTearDown(repository.dispose);
      addTearDown(sink.clear);

      expect(await repository.pendingCount.first, 2);
      expect(await repository.allSynced.first, isFalse);

      repository.setPendingCount(0);
      repository.setAllSynced(true);
      expect(await repository.pendingCount.first, 0);
      expect(await repository.allSynced.first, isTrue);

      sink.report(
        'incidents',
        const RepositoryError(
          operation: 'reportIncident',
          message: 'Write failed',
          documentId: 'incident-1',
        ),
      );
      expect((await repository.writeFailures.first), hasLength(1));
      repository.clearWriteFailures();
      expect(await repository.writeFailures.first, isEmpty);
    });
  });

  test(
    'fake sync status receives failures from its subscribed sink stream',
    () async {
      final sink = WriteFailureSink();
      final repository = FakeSyncStatusRepository(failureSink: sink);
      addTearDown(repository.dispose);
      addTearDown(sink.clear);

      final failureFuture = repository.writeFailures.firstWhere(
        (failures) => failures.isNotEmpty,
      );
      sink.report(
        'workers',
        const RepositoryError(
          operation: 'saveWorker',
          message: 'permission denied',
          documentId: 'worker-id',
        ),
      );

      final failures = await failureFuture;
      expect(failures.single.message, 'permission denied');
    },
  );

  test(
    'Firestore sync status receives failures from its subscribed sink stream',
    () async {
      final sink = WriteFailureSink();
      final repository = FirestoreSyncStatusRepository(
        firestore: _MockFirebaseFirestore(),
        auth: _MockFirebaseAuth(),
        failureSink: sink,
      );
      addTearDown(sink.clear);

      final failureFuture = repository.writeFailures.firstWhere(
        (failures) => failures.isNotEmpty,
      );
      sink.report(
        'workers',
        const RepositoryError(
          operation: 'saveWorker',
          message: 'permission denied',
          documentId: 'worker-id',
        ),
      );

      final failures = await failureFuture;
      expect(failures.single.message, 'permission denied');
    },
  );

  test('provider forwards repository failures into sync status', () async {
    writeFailureSink.clear();
    addTearDown(writeFailureSink.clear);
    final syncStatus = FakeSyncStatusRepository(failureSink: writeFailureSink);
    final container = ProviderContainer(
      overrides: fakeRepositoryOverrides(syncStatusRepository: syncStatus),
    );
    addTearDown(container.dispose);

    final materialRepository = container.read(materialRepositoryProvider);
    final disposals = <void Function()>[];
    forwardRepositoryFailures(
      errorStream: materialRepository.errorStream,
      collection: 'materialLogs',
      onDispose: disposals.add,
      collectionForError: (error) =>
          error.operation == 'saveMaterial' ? 'materials' : 'materialLogs',
    );
    addTearDown(() {
      for (final dispose in disposals) {
        dispose();
      }
      syncStatus.dispose();
    });
    materialRepository.logUsage(materialId: 'missing-material', qtyUsed: 1);

    final failures = await container
        .read(syncStatusRepositoryProvider)
        .writeFailures
        .firstWhere(
      (items) => items.isNotEmpty,
    );
    final failure = failures.single;
    expect(failure.collection, 'materialLogs');
    expect(failure.documentId, isNotEmpty);
    expect(failure.message, contains('does not exist'));
  });
}
