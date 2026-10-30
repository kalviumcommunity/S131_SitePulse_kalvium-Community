import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class IncidentRepository {
  /// Watch incidents. Supervisor passes siteId. PM passes null for all sites or specific siteId,
  /// with date-range filters and optional severity filter.
  Stream<List<Incident>> watchIncidents({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  });

  /// Fire-and-forget write: returns incident ID immediately
  String reportIncident(Incident incident);

  Stream<RepositoryError> get errorStream;
}
