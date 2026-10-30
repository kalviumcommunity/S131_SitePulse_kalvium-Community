import 'dart:async';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';

class FakeWorkerRepository implements WorkerRepository {
  static List<Worker> get defaultWorkers => [
        // Site 1 workers (~10)
        const Worker(id: 'w-101', name: 'Ramesh Patel', trade: 'Mason', workerCode: 'MAS-101', active: true, siteId: 'site-1'),
        const Worker(id: 'w-102', name: 'Arjun Das', trade: 'Carpenter', workerCode: 'CAR-102', active: true, siteId: 'site-1'),
        const Worker(id: 'w-103', name: 'Vikram Singh', trade: 'Electrician', workerCode: 'ELE-103', active: true, siteId: 'site-1'),
        const Worker(id: 'w-104', name: 'Anil Kumar', trade: 'Plumber', workerCode: 'PLU-104', active: true, siteId: 'site-1'),
        const Worker(id: 'w-105', name: 'Deepak Rao', trade: 'Welder', workerCode: 'WEL-105', active: true, siteId: 'site-1'),
        const Worker(id: 'w-106', name: 'Manoj Verma', trade: 'Painter', workerCode: 'PAI-106', active: true, siteId: 'site-1'),
        const Worker(id: 'w-107', name: 'Gopal Yadav', trade: 'Steel Fixer', workerCode: 'STL-107', active: true, siteId: 'site-1'),
        const Worker(id: 'w-108', name: 'Sunil Sharma', trade: 'Helper', workerCode: 'HLP-108', active: true, siteId: 'site-1'),
        const Worker(id: 'w-109', name: 'Kishore Jena', trade: 'Foreman', workerCode: 'FOR-109', active: true, siteId: 'site-1'),
        const Worker(id: 'w-110', name: 'Bhavin Shah', trade: 'Crane Operator', workerCode: 'CRN-110', active: false, siteId: 'site-1'),

        // Site 2 workers (~10)
        const Worker(id: 'w-201', name: 'Pankaj Roy', trade: 'Mason', workerCode: 'MAS-201', active: true, siteId: 'site-2'),
        const Worker(id: 'w-202', name: 'Santosh Gowda', trade: 'Carpenter', workerCode: 'CAR-202', active: true, siteId: 'site-2'),
        const Worker(id: 'w-203', name: 'Mohammed Ali', trade: 'Electrician', workerCode: 'ELE-203', active: true, siteId: 'site-2'),
        const Worker(id: 'w-204', name: 'Subhash Nair', trade: 'Plumber', workerCode: 'PLU-204', active: true, siteId: 'site-2'),
        const Worker(id: 'w-205', name: 'Rajesh Gupta', trade: 'Welder', workerCode: 'WEL-205', active: true, siteId: 'site-2'),
        const Worker(id: 'w-206', name: 'Vijay Pillai', trade: 'Painter', workerCode: 'PAI-206', active: true, siteId: 'site-2'),
        const Worker(id: 'w-207', name: 'Harish Babu', trade: 'Steel Fixer', workerCode: 'STL-207', active: true, siteId: 'site-2'),
        const Worker(id: 'w-208', name: 'Ashok Meena', trade: 'Helper', workerCode: 'HLP-208', active: true, siteId: 'site-2'),
        const Worker(id: 'w-209', name: 'Vinod Tiwari', trade: 'Foreman', workerCode: 'FOR-209', active: true, siteId: 'site-2'),
        const Worker(id: 'w-210', name: 'Manish Soni', trade: 'Helper', workerCode: 'HLP-210', active: false, siteId: 'site-2'),

        // Site 3 workers (~10)
        const Worker(id: 'w-301', name: 'Sanjay Reddy', trade: 'Mason', workerCode: 'MAS-301', active: true, siteId: 'site-3'),
        const Worker(id: 'w-302', name: 'Karthik Raja', trade: 'Carpenter', workerCode: 'CAR-302', active: true, siteId: 'site-3'),
        const Worker(id: 'w-303', name: 'Naveen Kumar', trade: 'Electrician', workerCode: 'ELE-303', active: true, siteId: 'site-3'),
        const Worker(id: 'w-304', name: 'Prashant More', trade: 'Plumber', workerCode: 'PLU-304', active: true, siteId: 'site-3'),
        const Worker(id: 'w-305', name: 'Ravi Teja', trade: 'Welder', workerCode: 'WEL-305', active: true, siteId: 'site-3'),
        const Worker(id: 'w-306', name: 'Govind Joshi', trade: 'Painter', workerCode: 'PAI-306', active: true, siteId: 'site-3'),
        const Worker(id: 'w-307', name: 'Dinesh Chauhan', trade: 'Steel Fixer', workerCode: 'STL-307', active: true, siteId: 'site-3'),
        const Worker(id: 'w-308', name: 'Mohan Lal', trade: 'Helper', workerCode: 'HLP-308', active: true, siteId: 'site-3'),
        const Worker(id: 'w-309', name: 'Lalit Negi', trade: 'Foreman', workerCode: 'FOR-309', active: true, siteId: 'site-3'),
        const Worker(id: 'w-310', name: 'Mukesh Pal', trade: 'Helper', workerCode: 'HLP-310', active: true, siteId: 'site-3'),
      ];

  // Map siteId -> (workerId -> Worker)
  final Map<String, Map<String, Worker>> _workersBySite = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeWorkerRepository({List<Worker>? initialWorkers}) {
    final list = initialWorkers ?? defaultWorkers;
    for (final w in list) {
      final sId = w.siteId ?? '';
      _workersBySite.putIfAbsent(sId, () => {})[w.id] = w;
    }
  }

  @override
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly}) async* {
    yield _filterWorkers(siteId, activeOnly);
    yield* _changeController.stream.map((_) => _filterWorkers(siteId, activeOnly));
  }

  @override
  Stream<List<Worker>> watchAllWorkers({bool? activeOnly}) async* {
    yield _allWorkers(activeOnly);
    yield* _changeController.stream.map((_) => _allWorkers(activeOnly));
  }

  List<Worker> _filterWorkers(String siteId, bool? activeOnly) {
    final map = _workersBySite[siteId] ?? {};
    return map.values.where((w) {
      if (activeOnly != null && w.active != activeOnly) return false;
      return true;
    }).toList();
  }

  List<Worker> _allWorkers(bool? activeOnly) {
    final all = <Worker>[];
    for (final map in _workersBySite.values) {
      for (final w in map.values) {
        if (activeOnly == null || w.active == activeOnly) {
          all.add(w);
        }
      }
    }
    return all;
  }

  @override
  Stream<Worker?> watchWorker(String siteId, String workerId) async* {
    yield _workersBySite[siteId]?[workerId];
    yield* _changeController.stream.map((_) => _workersBySite[siteId]?[workerId]);
  }

  @override
  String saveWorker(String siteId, Worker worker) {
    if (worker.id.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'saveWorker',
          message: 'Worker id cannot be empty',
        ),
      );
      return '';
    }
    final effective = worker.siteId == null ? worker.copyWith(siteId: siteId) : worker;
    _workersBySite.putIfAbsent(siteId, () => {})[worker.id] = effective;
    _changeController.add(null);
    return worker.id;
  }

  @override
  String toggleWorkerActive(String siteId, String workerId, bool active) {
    final current = _workersBySite[siteId]?[workerId];
    if (current == null) {
      _errorController.add(
        RepositoryError(
          operation: 'toggleWorkerActive',
          message: 'Worker $workerId not found at site $siteId',
          documentId: workerId,
        ),
      );
      return workerId;
    }
    _workersBySite[siteId]![workerId] = current.copyWith(active: active);
    _changeController.add(null);
    return workerId;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _changeController.close();
    _errorController.close();
  }
}
