import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/features/supervisor/roster/roster_screen.dart';
import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';

class _CountingWorkerRepository extends FakeWorkerRepository {
  int watchWorkersCalls = 0;

  @override
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly}) {
    watchWorkersCalls++;
    return super.watchWorkers(siteId, activeOnly: activeOnly);
  }
}

class _RecordingWorkerRepository extends FakeWorkerRepository {
  String? savedWorkerId;
  String? returnedWorkerId;

  @override
  String saveWorker(String siteId, Worker worker) {
    savedWorkerId = worker.id;
    returnedWorkerId = super.saveWorker(siteId, worker);
    return returnedWorkerId!;
  }
}

void main() {
  testWidgets('signed-out roster makes no repository query and disables add', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository()..signOut();
    final workerRepository = _CountingWorkerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(
          authRepository: authRepository,
          workerRepository: workerRepository,
        ),
        child: const MaterialApp(home: RosterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No project site is assigned to this account.'),
      findsOneWidget,
    );
    expect(workerRepository.watchWorkersCalls, 0);
    expect(
      tester
          .widget<FloatingActionButton>(find.byKey(const Key('add_worker_fab')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('roster creates and retains one UUID for a new worker', (
    tester,
  ) async {
    const supervisor = AppUser(
      uid: 'supervisor-test',
      role: UserRole.supervisor,
      name: 'Supervisor',
      siteId: 'site-1',
    );
    final authRepository = FakeAuthRepository(initialUser: supervisor);
    final workerRepository = _RecordingWorkerRepository();
    addTearDown(authRepository.dispose);
    addTearDown(workerRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(
          authRepository: authRepository,
          workerRepository: workerRepository,
        ),
        child: const MaterialApp(home: RosterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_worker_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add_worker_name_field')),
      'Test Worker',
    );
    await tester.enterText(
      find.byKey(const Key('add_worker_code_field')),
      'TST-999',
    );
    await tester.tap(find.byKey(const Key('save_worker_button')));
    await tester.pumpAndSettle();

    expect(
      workerRepository.savedWorkerId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(workerRepository.returnedWorkerId, workerRepository.savedWorkerId);
  });
}
