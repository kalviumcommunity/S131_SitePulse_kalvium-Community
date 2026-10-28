import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';
import 'package:site_pulse/features/auth/auth_failure.dart';
import 'package:site_pulse/features/auth/login_screen.dart';

Widget createTestWidget({SignInFn? signInOverride}) {
  return ProviderScope(
    overrides: [
      if (signInOverride != null)
        signInOverrideProvider.overrideWithValue(signInOverride),
    ],
    child: MaterialApp(
      theme: buildTheme(),
      home: const LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen Form Validation Tests', () {
    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap Sign In without filling in any fields
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error when email is invalid', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byKey(const Key('email_field')), 'not-an-email');
      await tester.enterText(find.byKey(const Key('password_field')), 'SomePassword123');

      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Password is required'), findsNothing);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final passwordFinder = find.byKey(const Key('password_field'));
      TextField textField = tester.widget(find.descendant(
        of: passwordFinder,
        matching: find.byType(TextField),
      ));
      expect(textField.obscureText, isTrue);

      // Tap visibility toggle
      await tester.tap(find.byKey(const Key('password_visibility_button')));
      await tester.pumpAndSettle();

      textField = tester.widget(find.descendant(
        of: passwordFinder,
        matching: find.byType(TextField),
      ));
      expect(textField.obscureText, isFalse);
    });
  });

  group('LoginScreen Error Mapping Tests', () {
    testWidgets('displays inline error for invalidCredentials', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signInOverride: (email, password) =>
            throw const AuthFailure(AuthFailureCode.invalidCredentials),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'WrongPass');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Wrong email or password'), findsOneWidget);
    });

    testWidgets('displays inline error for noNetwork', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signInOverride: (email, password) =>
            throw const AuthFailure(AuthFailureCode.noNetwork),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('No network connection'), findsOneWidget);
    });

    testWidgets('displays inline error for accountNotSetUp', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signInOverride: (email, password) =>
            throw const AuthFailure(AuthFailureCode.accountNotSetUp),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'unknown@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('This account is not set up. Contact your admin.'), findsOneWidget);
    });

    testWidgets('displays inline error for unknown failure', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signInOverride: (email, password) =>
            throw const AuthFailure(AuthFailureCode.unknown),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    testWidgets('shows loading indicator while signing in', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signInOverride: (email, password) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return const AppUser(
            uid: 'user-sup-1',
            role: UserRole.supervisor,
            name: 'Suresh Kumar',
            siteId: 'site-1',
          );
        },
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'sup1@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');

      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pump(); // Start async sign in

      // Loading spinner is present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle(); // Finish sign in
    });
  });
}
