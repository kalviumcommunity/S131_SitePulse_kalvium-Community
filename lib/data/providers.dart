import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/data/repositories/firestore/firestore.dart';

/// Set to `false` to switch from in-memory fakes to real Firestore
/// repositories for sites, workers and attendance.
const bool useFakes = true;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FakeAuthRepository();
});

final siteRepositoryProvider = Provider<SiteRepository>((ref) {
  if (useFakes) return FakeSiteRepository();
  final repository = FirestoreSiteRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  if (useFakes) return FakeWorkerRepository();
  final repository = FirestoreWorkerRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  if (useFakes) return FakeAttendanceRepository();
  final repository = FirestoreAttendanceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return FakeMaterialRepository();
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return FakeIncidentRepository();
});
