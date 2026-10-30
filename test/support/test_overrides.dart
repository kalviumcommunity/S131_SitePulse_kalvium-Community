import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/sync_status_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'fakes/fakes.dart';

List<Override> fakeRepositoryOverrides({
  AuthRepository? authRepository,
  SiteRepository? siteRepository,
  WorkerRepository? workerRepository,
  AttendanceRepository? attendanceRepository,
  MaterialRepository? materialRepository,
  IncidentRepository? incidentRepository,
  SyncStatusRepository? syncStatusRepository,
}) {
  return [
    authRepositoryProvider.overrideWithValue(
      authRepository ?? FakeAuthRepository(),
    ),
    siteRepositoryProvider.overrideWithValue(
      siteRepository ?? FakeSiteRepository(),
    ),
    workerRepositoryProvider.overrideWithValue(
      workerRepository ?? FakeWorkerRepository(),
    ),
    attendanceRepositoryProvider.overrideWithValue(
      attendanceRepository ?? FakeAttendanceRepository(),
    ),
    materialRepositoryProvider.overrideWithValue(
      materialRepository ?? FakeMaterialRepository(),
    ),
    incidentRepositoryProvider.overrideWithValue(
      incidentRepository ?? FakeIncidentRepository(),
    ),
    syncStatusRepositoryProvider.overrideWithValue(
      syncStatusRepository ?? FakeSyncStatusRepository(),
    ),
  ];
}
