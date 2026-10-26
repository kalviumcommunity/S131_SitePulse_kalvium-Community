import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FakeAuthRepository();
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  return FakeSiteRepository();
});

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return FakeWorkerRepository();
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return FakeAttendanceRepository();
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return FakeMaterialRepository();
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return FakeIncidentRepository();
});
