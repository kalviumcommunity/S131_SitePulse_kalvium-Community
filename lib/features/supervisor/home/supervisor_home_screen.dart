import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Home'),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 64, color: Colors.brown),
              const SizedBox(height: 16),
              Text(
                'Supervisor Dashboard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${user?.name ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Role: ${user?.role.name ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Site ID: ${user?.siteId ?? 'None'}',
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('logout_button_large'),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () => ref.read(authControllerProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
