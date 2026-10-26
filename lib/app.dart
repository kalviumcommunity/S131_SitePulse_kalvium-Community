import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'router.dart';

class SitePulseApp extends StatelessWidget {
  SitePulseApp({super.key, required this.firebaseReady})
      : _router = buildRouter(firebaseReady: firebaseReady);

  final bool firebaseReady;
  final dynamic _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Site Pulse',
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}