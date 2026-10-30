import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fake_auth_repository.dart';
import 'package:site_pulse/router.dart';

Widget createRouterTestApp({
  required FakeAuthRepository fakeAuthRepo,
  String? initialLocation,
}) {
  final router = buildRouter(
    firebaseReady: true,
    authRepository: fakeAuthRepo,
    initialLocation: initialLocation,
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuthRepo),
    ],
    child: MaterialApp.router(
      theme: buildTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('GoRouter Auth & Role Redirect Tests', () {
    testWidgets('redirects unauthenticated user to /login', (tester) async {
      final fakeAuth = FakeAuthRepository(initialUser: null);
      fakeAuth.signOut();

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();

      // Expect to be redirected to login screen
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
    });

    testWidgets('redirects supervisor to /supervisor/home on login', (tester) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/login',
      ));
      await tester.pumpAndSettle();

      // Expect to be redirected to supervisor home
      expect(find.text('Supervisor Home'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('Name: Suresh Kumar'), findsNothing);
      expect(find.text('Role: supervisor'), findsNothing);
    });

    testWidgets('redirects PM to /pm/dashboard on login', (tester) async {
      const pm = AppUser(
        uid: 'user-pm-1',
        role: UserRole.pm,
        name: 'Priya Sharma',
        siteId: null,
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [pm],
        initialUser: pm,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/login',
      ));
      await tester.pumpAndSettle();

      // Expect to be redirected to PM dashboard
      expect(find.text('PM Dashboard'), findsOneWidget);
      expect(find.text('Name: Priya Sharma'), findsOneWidget);
      expect(find.text('Role: pm'), findsOneWidget);
    });

    testWidgets('redirects supervisor away from any /pm route', (tester) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/pm/dashboard',
      ));
      await tester.pumpAndSettle();

      // Must be redirected away from /pm to supervisor home
      expect(find.text('Supervisor Home'), findsOneWidget);
      expect(find.text('PM Dashboard'), findsNothing);
    });

    testWidgets('redirects PM away from any /supervisor route', (tester) async {
      const pm = AppUser(
        uid: 'user-pm-1',
        role: UserRole.pm,
        name: 'Priya Sharma',
        siteId: null,
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [pm],
        initialUser: pm,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();

      // Must be redirected away from /supervisor to PM dashboard
      expect(find.text('PM Dashboard'), findsOneWidget);
      expect(find.text('Supervisor Home'), findsNothing);
    });

    testWidgets('logging out redirects back to /login screen', (tester) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Supervisor Home'), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logout_confirmation_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      // Expect to be redirected back to /login
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
    });

    testWidgets('supervisor footer has Home, Roster and Profile tabs', (
      tester,
    ) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Roster'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Roster'));
      await tester.pumpAndSettle();
      expect(find.text('Worker Roster'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Supervisor Home'), findsOneWidget);
    });

    testWidgets('supervisor action routes hide the footer', (tester) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();

      for (final entry in [
        (const Key('action_attendance'), 'Attendance'),
        (const Key('action_material'), 'Material Usage'),
        (const Key('action_incident'), 'Safety Incidents'),
      ]) {
        await tester.tap(find.byKey(entry.$1));
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsWidgets);
        expect(find.byType(NavigationBar), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('supervisor header opens profile with name, site and email', (
      tester,
    ) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
        email: 'sup1@sitepulse.test',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('supervisor_profile_card')));
      await tester.pumpAndSettle();

      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('Downtown Heights'), findsOneWidget);
      expect(find.text('sup1@sitepulse.test'), findsOneWidget);
    });

    testWidgets('profile logout also requires confirmation', (tester) async {
      const supervisor = AppUser(
        uid: 'user-sup-1',
        role: UserRole.supervisor,
        name: 'Suresh Kumar',
        siteId: 'site-1',
      );
      final fakeAuth = FakeAuthRepository(
        initialUsers: [supervisor],
        initialUser: supervisor,
      );

      await tester.pumpWidget(createRouterTestApp(
        fakeAuthRepo: fakeAuth,
        initialLocation: '/supervisor/home',
      ));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.person),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Profile'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_logout_button')),
        200,
      );
      await tester.ensureVisible(find.byKey(const Key('profile_logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile_logout_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('logout_confirmation_dialog')), findsOneWidget);
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
