import 'package:site_pulse/data/models/write_failure.dart';

abstract class SyncStatusRepository {
  Stream<List<WriteFailure>> get writeFailures;
  void clearWriteFailures();
  Stream<int> get pendingCount;
  Stream<bool> get allSynced;
}
