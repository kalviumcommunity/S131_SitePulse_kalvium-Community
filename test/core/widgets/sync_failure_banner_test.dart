import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/widgets/sync_failure_banner.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fake_auth_repository.dart';
import 'package:site_pulse/data/repositories/fakes/fake_sync_status_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/write_failure_sink.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

void main() {
  testWidgets('supervisor can see and clear durable write failures', (
    tester,
  ) async {
    const supervisor = AppUser(
      uid: 'supervisor-test',
      role: UserRole.supervisor,
      name: 'Supervisor',
      siteId: 'site-test',
    );
    final sink = WriteFailureSink();
    final syncStatus = FakeSyncStatusRepository(failureSink: sink);
    final authRepository = FakeAuthRepository(initialUser: supervisor);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        syncStatusRepositoryProvider.overrideWithValue(syncStatus),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(syncStatus.dispose);
    addTearDown(authRepository.dispose);
    addTearDown(sink.clear);
    final observedFailures = <List<WriteFailure>>[];
    final failureSubscription = container
        .read(syncStatusRepositoryProvider)
        .writeFailures
        .listen(observedFailures.add);
    addTearDown(failureSubscription.cancel);

    expect(
      identical(container.read(syncStatusRepositoryProvider), syncStatus),
      isTrue,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncFailureBanner(child: Scaffold(body: Text('Screen'))),
        ),
      ),
    );
    await tester.pump();
    expect(container.read(authStateProvider).asData?.value, supervisor);

    sink.report(
      'workers',
      const RepositoryError(
        operation: 'saveWorker',
        message: 'permission denied',
        documentId: 'worker-id',
      ),
    );
    await tester.pumpAndSettle();
    expect(observedFailures.last.single.message, 'permission denied');

    expect(
      find.textContaining('A save could not be synced: permission denied'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(
      find.textContaining('A save could not be synced: permission denied'),
      findsNothing,
    );
  });
}
