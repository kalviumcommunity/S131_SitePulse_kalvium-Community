import 'package:flutter/material.dart';

/// Temporary screen proving the app boots and Firebase is initialised.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_heart, size: 64),
            const SizedBox(height: 12),
            Text('Site Pulse', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(firebaseReady ? 'Firebase connected' : 'Firebase not initialised'),
          ],
        ),
      ),
    );
  }
}