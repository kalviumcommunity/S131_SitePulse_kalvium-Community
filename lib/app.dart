import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'router.dart';

class SitePulseApp extends ConsumerStatefulWidget {
  const SitePulseApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  ConsumerState<SitePulseApp> createState() => _SitePulseAppState();
}

class _SitePulseAppState extends ConsumerState<SitePulseApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authRepository = ref.read(authRepositoryProvider);
    _router = buildRouter(
      firebaseReady: widget.firebaseReady,
      authRepository: authRepository,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Site Pulse',
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
