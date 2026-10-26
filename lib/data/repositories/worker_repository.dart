import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class WorkerRepository {
  /// Reads workers for a specific site (supervisor or PM site detail)
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly});

  /// Reads all workers across all sites (PM overview)
  Stream<List<Worker>> watchAllWorkers({bool? activeOnly});

  /// Reads a single worker
  Stream<Worker?> watchWorker(String siteId, String workerId);

  /// Fire-and-forget write: returns worker ID immediately
  String saveWorker(String siteId, Worker worker);

  /// Fire-and-forget toggle: returns worker ID immediately
  String toggleWorkerActive(String siteId, String workerId, bool active);

  Stream<RepositoryError> get errorStream;
}
