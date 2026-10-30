import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart' as repository;
import 'package:site_pulse/features/auth/login_screen.dart';
import '../../support/fakes/fake_auth_repository.dart';
import '../../support/test_overrides.dart';

class _LoginAuthRepository extends FakeAuthRepository {
  _LoginAuthRepository({this.failure, this.delaySignIn = false});

  final repository.AuthFailure? failure;
  final bool delaySignIn;

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (delaySignIn) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (failure case final failure?) {
      throw failure;
    }
    return super.signIn(email, password);
  }
}

Widget createTestWidget({
  repository.AuthFailure? failure,
  bool delaySignIn = false,
}) {
  return ProviderScope(
    overrides: fakeRepositoryOverrides(
      authRepository: _LoginAuthRepository(
        failure: failure,
        delaySignIn: delaySignIn,
      ),
    ),
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
        failure: const repository.AuthFailure(
          code: repository.AuthFailureCode.invalidCredentials,
          message: 'Invalid credentials',
        ),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'WrongPass');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Wrong email or password'), findsOneWidget);
    });

    testWidgets('displays inline error for noNetwork', (tester) async {
      await tester.pumpWidget(createTestWidget(
        failure: const repository.AuthFailure(
          code: repository.AuthFailureCode.noNetwork,
          message: 'No network',
        ),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('No network connection'), findsOneWidget);
    });

    testWidgets('displays inline error for accountNotSetUp', (tester) async {
      await tester.pumpWidget(createTestWidget(
        failure: const repository.AuthFailure(
          code: repository.AuthFailureCode.accountNotSetUp,
          message: 'Account not set up',
        ),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'unknown@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('This account is not set up. Contact your admin.'), findsOneWidget);
    });

    testWidgets('displays inline error for unknown failure', (tester) async {
      await tester.pumpWidget(createTestWidget(
        failure: const repository.AuthFailure(
          code: repository.AuthFailureCode.unknown,
          message: 'Unknown error',
        ),
      ));

      await tester.enterText(find.byKey(const Key('email_field')), 'user@sitepulse.test');
      await tester.enterText(find.byKey(const Key('password_field')), 'SitePulse#2026');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    });

    testWidgets('shows loading indicator while signing in', (tester) async {
      await tester.pumpWidget(createTestWidget(
        delaySignIn: true,
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
