import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/utils/logout_confirmation.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

final _supervisorProfileSiteProvider = StreamProvider.autoDispose
    .family<Site?, String>((ref, siteId) {
      return ref.watch(siteRepositoryProvider).watchSite(siteId);
    });

final _supervisorProfileWorkersProvider = StreamProvider.autoDispose
    .family<List<Worker>, String>((ref, siteId) {
      return ref
          .watch(workerRepositoryProvider)
          .watchWorkers(siteId, activeOnly: true);
    });

class SupervisorProfileScreen extends ConsumerWidget {
  const SupervisorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final siteId = user?.siteId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: OfflineBanner(),
        ),
      ),
      body: AppPageBackground(
        child: user == null
            ? const EmptyView(message: 'No signed-in user is available.')
            : siteId == null || siteId.isEmpty
            ? const EmptyView(
                message: 'No project site is assigned to this account.',
              )
            : _buildProfile(context, ref, user, siteId),
      ),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
    String siteId,
  ) {
    final siteAsync = ref.watch(_supervisorProfileSiteProvider(siteId));
    final workersAsync = ref.watch(_supervisorProfileWorkersProvider(siteId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              _ProfileValue(label: 'Name', value: user.name),
              _ProfileValue(label: 'Role', value: user.role.name),
              _ProfileValue(label: 'Email', value: user.email ?? 'Unavailable'),
              _ProfileValue(label: 'User ID', value: user.uid, muted: true),
              _ProfileAsyncValue<Site?>(
                label: 'Site',
                value: siteAsync,
                display: (site) => site?.name ?? 'Unknown site',
              ),
              _ProfileValue(label: 'Site ID', value: siteId, muted: true),
              _ProfileAsyncValue<Site?>(
                label: 'Last entry',
                value: siteAsync,
                display: _formatLastEntry,
              ),
              _ProfileAsyncValue<List<Worker>>(
                label: 'Active workers',
                value: workersAsync,
                display: (workers) => '${workers.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('profile_logout_button'),
          onPressed: () => showLogoutConfirmation(
            context,
            () => ref.read(authControllerProvider).signOut(),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }

  String _formatLastEntry(Site? site) {
    final lastEntryAt = site?.lastEntryAt;
    if (lastEntryAt == null) return 'No entries recorded';
    return DateFormat('dd MMM yyyy, HH:mm').format(lastEntryAt);
  }
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(
        value,
        style: TextStyle(
          color: muted ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: muted ? 12 : 14,
        ),
      ),
    );
  }
}

class _ProfileAsyncValue<T> extends StatelessWidget {
  const _ProfileAsyncValue({
    required this.label,
    required this.value,
    required this.display,
  });

  final String label;
  final AsyncValue<T> value;
  final String Function(T value) display;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () =>
          ListTile(title: Text(label), subtitle: const Text('Loading…')),
      error: (error, _) =>
          ListTile(title: Text(label), subtitle: Text('Unavailable: $error')),
      data: (data) => _ProfileValue(label: label, value: display(data)),
    );
  }
}
