import 'dart:async';

import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/repositories/sync_status_repository.dart';
import 'package:site_pulse/data/repositories/write_failure_sink.dart';

class FakeSyncStatusRepository implements SyncStatusRepository {
  factory FakeSyncStatusRepository({
    int pendingCount = 0,
    bool allSynced = true,
    WriteFailureSink? failureSink,
  }) => FakeSyncStatusRepository._(
    pendingCount,
    allSynced,
    failureSink ?? writeFailureSink,
  );

  FakeSyncStatusRepository._(
    this._pendingCount,
    this._allSynced,
    this._failureSink,
  );

  int _pendingCount;
  bool _allSynced;
  final WriteFailureSink _failureSink;
  final _pendingCountController = StreamController<int>.broadcast();
  final _allSyncedController = StreamController<bool>.broadcast();

  @override
  Stream<List<WriteFailure>> get writeFailures => _failureSink.failures;

  @override
  void clearWriteFailures() => _failureSink.clear();

  @override
  Stream<int> get pendingCount async* {
    yield _pendingCount;
    yield* _pendingCountController.stream;
  }

  @override
  Stream<bool> get allSynced async* {
    yield _allSynced;
    yield* _allSyncedController.stream;
  }

  void setPendingCount(int count) {
    _pendingCount = count;
    _pendingCountController.add(count);
  }

  void setAllSynced(bool value) {
    _allSynced = value;
    _allSyncedController.add(value);
  }

  void dispose() {
    _pendingCountController.close();
    _allSyncedController.close();
  }
}
