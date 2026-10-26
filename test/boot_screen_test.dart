import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/features/auth/boot_screen.dart';

void main() {
  testWidgets('boot screen shows app name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const BootScreen(firebaseReady: true)),
    );
    expect(find.text('Site Pulse'), findsOneWidget);
    expect(find.text('Firebase connected'), findsOneWidget);
  });
}