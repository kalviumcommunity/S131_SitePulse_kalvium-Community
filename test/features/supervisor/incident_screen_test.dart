import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/fakes/fakes.dart';
import 'package:site_pulse/features/supervisor/incident/incident_screen.dart';

Widget buildScreen({FakeIncidentRepository? incidentRepo, FakeAuthRepository? authRepo}) {
  const initialUser = AppUser(
    uid: 'sup-1',
    name: 'Test Supervisor',
    role: UserRole.supervisor,
    siteId: 'site-1',
  );
  final actualAuth = authRepo ??
      FakeAuthRepository(
        initialUser: initialUser,
        initialUsers: [initialUser],
      );
  final actualIncident = incidentRepo ?? FakeIncidentRepository();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(actualAuth),
      incidentRepositoryProvider.overrideWithValue(actualIncident),
    ],
    child: const MaterialApp(home: IncidentScreen()),
  );
}

void main() {
  group('IncidentScreen Widget Tests', () {
    testWidgets('renders form fields and submit button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('severity_minor')), findsOneWidget);
      expect(find.byKey(const Key('severity_critical')), findsOneWidget);
      expect(find.byKey(const Key('incident_description_field')), findsOneWidget);
      expect(find.byKey(const Key('submit_incident_button')), findsOneWidget);
    });

    testWidgets('submit button is disabled when description is shorter than 10 characters', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final btn = tester.widget<FilledButton>(find.byKey(const Key('submit_incident_button')));
      expect(btn.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('incident_description_field')), 'Short');
      await tester.pump();

      final btnStillDisabled = tester.widget<FilledButton>(find.byKey(const Key('submit_incident_button')));
      expect(btnStillDisabled.onPressed, isNull);
    });

    testWidgets('escalation warning shows when High or Critical selected, hides when Minor selected', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially Minor is selected, banner should not be present
      expect(find.byKey(const Key('escalation_banner')), findsNothing);

      // Tap High
      await tester.tap(find.byKey(const Key('severity_high')));
      await tester.pump();
      expect(find.byKey(const Key('escalation_banner')), findsOneWidget);

      // Tap Critical
      await tester.tap(find.byKey(const Key('severity_critical')));
      await tester.pump();
      expect(find.byKey(const Key('escalation_banner')), findsOneWidget);

      // Tap Minor
      await tester.tap(find.byKey(const Key('severity_minor')));
      await tester.pump();
      expect(find.byKey(const Key('escalation_banner')), findsNothing);
    });

    testWidgets('tapping submit opens confirmation dialog', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('incident_description_field')),
        'Valid description exceeding ten chars',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('submit_incident_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('incident_confirm_dialog')), findsOneWidget);
      expect(find.text('This record cannot be edited after submitting.'), findsOneWidget);
    });

    testWidgets('confirming submit dialog reports incident and shows saved snackbar', (tester) async {
      final repo = FakeIncidentRepository(initialIncidents: []);
      await tester.pumpWidget(buildScreen(incidentRepo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.byKey(const Key('incident_description_field')),
        'Scaffolding issue on floor 3 reported by team',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('submit_incident_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Saved on this device'), findsOneWidget);
      // Verify description cleared
      final field = tester.widget<TextFormField>(find.byKey(const Key('incident_description_field')));
      expect(field.controller?.text, isEmpty);
    });
  });

  group('isHighSeverity Threshold Pure Function Tests', () {
    test('returns true for high and critical', () {
      expect(isHighSeverity(Severity.high), isTrue);
      expect(isHighSeverity(Severity.critical), isTrue);
    });

    test('returns false for minor and moderate', () {
      expect(isHighSeverity(Severity.minor), isFalse);
      expect(isHighSeverity(Severity.moderate), isFalse);
    });
  });

  group('FakeIncidentRepository Integration Tests', () {
    test('watchIncidents emits seeded list', () async {
      final repo = FakeIncidentRepository();
      final list = await repo.watchIncidents().first;
      expect(list.length, greaterThanOrEqualTo(1));
    });

    test('reportIncident adds and emits new incident', () async {
      final repo = FakeIncidentRepository(initialIncidents: []);
      final incident = Incident(
        id: 'test-inc-1',
        severity: Severity.high,
        description: 'Crane hook inspection failed',
        occurredAt: DateTime.now(),
        siteId: 'site-1',
      );

      final returnedId = repo.reportIncident(incident);
      expect(returnedId, equals('test-inc-1'));

      final list = await repo.watchIncidents().first;
      expect(list.length, equals(1));
      expect(list.first.description, equals('Crane hook inspection failed'));
    });
  });
}
