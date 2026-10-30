import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class WorkerRepository {
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly});

  Stream<List<Worker>> watchAllWorkers();

  /// Returns immediately so callers never wait for offline writes.
  String saveWorker(String siteId, Worker worker);

  String toggleWorkerActive(String siteId, String workerId, bool active);

  Stream<RepositoryError> get errorStream;
}
