import 'dart:async';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

class FakeIncidentRepository implements IncidentRepository {
  static List<Incident> get defaultIncidents => [
        // One high severity incident
        Incident(
          id: 'inc-1',
          severity: Severity.high,
          description: 'Scaffolding joint failure on Level 4; area cordoned off',
          occurredAt: DateTime.now().subtract(const Duration(days: 1)),
          siteId: 'site-1',
        ),
        // One minor severity incident
        Incident(
          id: 'inc-2',
          severity: Severity.minor,
          description: 'Minor hand abrasion during rebar unloading; treated with first aid',
          occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
          siteId: 'site-2',
        ),
      ];

  final Map<String, Incident> _incidents = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeIncidentRepository({List<Incident>? initialIncidents}) {
    final list = initialIncidents ?? defaultIncidents;
    for (final inc in list) {
      _incidents[inc.id] = inc;
    }
  }

  @override
  Stream<List<Incident>> watchIncidents({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  }) async* {
    yield _filter(siteId: siteId, startDate: startDate, endDate: endDate, severity: severity);
    yield* _changeController.stream.map(
      (_) => _filter(siteId: siteId, startDate: startDate, endDate: endDate, severity: severity),
    );
  }

  List<Incident> _filter({
    String? siteId,
    DateTime? startDate,
    DateTime? endDate,
    Severity? severity,
  }) {
    return _incidents.values.where((inc) {
      if (siteId != null && inc.siteId != siteId) return false;
      if (severity != null && inc.severity != severity) return false;
      if (startDate != null && inc.occurredAt.isBefore(startDate)) return false;
      if (endDate != null && inc.occurredAt.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  @override
  Stream<Incident?> watchIncident(String id) async* {
    yield _incidents[id];
    yield* _changeController.stream.map((_) => _incidents[id]);
  }

  @override
  String reportIncident(Incident incident) {
    if (incident.id.isEmpty) {
      _errorController.add(
        const RepositoryError(
          operation: 'reportIncident',
          message: 'Incident id cannot be empty',
        ),
      );
      return '';
    }
    _incidents[incident.id] = incident;
    _changeController.add(null);
    return incident.id;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _changeController.close();
    _errorController.close();
  }
}
