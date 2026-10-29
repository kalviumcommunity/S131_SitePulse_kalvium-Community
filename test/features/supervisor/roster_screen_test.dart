import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/features/supervisor/roster/roster_screen.dart';

class _CountingWorkerRepository extends FakeWorkerRepository {
  int watchWorkersCalls = 0;

  @override
  Stream<List<Worker>> watchWorkers(String siteId, {bool? activeOnly}) {
    watchWorkersCalls++;
    return super.watchWorkers(siteId, activeOnly: activeOnly);
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
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          workerRepositoryProvider.overrideWithValue(workerRepository),
        ],
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
}
