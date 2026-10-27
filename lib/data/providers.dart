import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';
import 'package:site_pulse/data/repositories/worker_repository.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';
import 'package:site_pulse/data/repositories/material_repository.dart';
import 'package:site_pulse/data/repositories/incident_repository.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/data/repositories/firestore/firestore_auth_repository.dart';

const useFakes = bool.fromEnvironment('USE_FAKES', defaultValue: true);

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final realAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirestoreAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (useFakes) {
    return FakeAuthRepository();
  }
  return ref.watch(realAuthRepositoryProvider);
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
