import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/utils/logout_confirmation.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

final _pmProfileSitesProvider = StreamProvider.autoDispose<List<Site>>((ref) {
  return ref.watch(siteRepositoryProvider).watchSites();
});

class PmProfileScreen extends ConsumerWidget {
  const PmProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final sitesAsync = ref.watch(_pmProfileSitesProvider);

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
            : sitesAsync.when(
                loading: () => const LoadingView(message: 'Loading profile…'),
                error: (error, _) => ErrorView(
                  message: 'Failed to load monitored sites: $error',
                  onRetry: () => ref.invalidate(_pmProfileSitesProvider),
                ),
                data: (sites) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          _ProfileValue(label: 'Name', value: user.name),
                          _ProfileValue(label: 'Role', value: user.role.name),
                          _ProfileValue(
                            label: 'Email',
                            value: user.email ?? 'Unavailable',
                          ),
                          _ProfileValue(
                            label: 'User ID',
                            value: user.uid,
                            muted: true,
                          ),
                          _ProfileValue(
                            label: 'Monitored sites',
                            value: '${sites.length}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('pm_profile_logout_button'),
                      onPressed: () => showLogoutConfirmation(
                        context,
                        () => ref.read(authControllerProvider).signOut(),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ),
      ),
    );
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
