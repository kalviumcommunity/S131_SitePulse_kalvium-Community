import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/write_failure.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

class SyncFailureBanner extends ConsumerStatefulWidget {
  final Widget child;

  const SyncFailureBanner({super.key, required this.child});

  @override
  ConsumerState<SyncFailureBanner> createState() => _SyncFailureBannerState();
}

class _SyncFailureBannerState extends ConsumerState<SyncFailureBanner> {
  late final Stream<List<WriteFailure>> _failures;

  @override
  void initState() {
    super.initState();
    _failures = ref.read(syncStatusRepositoryProvider).writeFailures;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    return StreamBuilder<List<WriteFailure>>(
      stream: _failures,
      builder: (context, snapshot) {
        final failures = snapshot.data;
        final showBanner =
            user?.role == UserRole.supervisor &&
            failures != null &&
            failures.isNotEmpty;

        return Column(
          children: [
            if (showBanner)
              MaterialBanner(
                content: Text(
                  'A save could not be synced: ${failures.first.message}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => ref
                        .read(syncStatusRepositoryProvider)
                        .clearWriteFailures(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}
