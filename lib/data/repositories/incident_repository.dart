import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class IncidentRepository {
  Stream<List<Incident>> watchIncidents({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  });

  /// Returns immediately so callers never wait for offline writes.
  String reportIncident(Incident incident);

  Stream<RepositoryError> get errorStream;
}
