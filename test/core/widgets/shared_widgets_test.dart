import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/widgets/widgets.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/incident.dart';

void main() {
  group('SyncChip Widget Tests', () {
    testWidgets('displays Pending state with amber clock icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncChip(pending: true),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
      expect(find.text('Synced'), findsNothing);
    });

    testWidgets('displays Synced state with check icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncChip(pending: false),
          ),
        ),
      );

      expect(find.text('Synced'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
    });
  });

  group('OfflineBanner Widget Tests', () {
    testWidgets('displays banner when offline override is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(overrideOffline: true),
          ),
        ),
      );

      expect(
        find.text('Offline - entries are saved on this device'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('hides banner when offline override is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(overrideOffline: false),
          ),
        ),
      );

      expect(
        find.text('Offline - entries are saved on this device'),
        findsNothing,
      );
    });
  });

  group('Status Views (LoadingView, EmptyView, ErrorView) Tests', () {
    testWidgets('LoadingView displays spinner and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingView(message: 'Loading materials...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading materials...'), findsOneWidget);
    });

    testWidgets('EmptyView displays message and triggers CTA', (tester) async {
      var ctaPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyView(
              message: 'No workers yet - add the first one',
              ctaLabel: 'Add Worker',
              onCta: () => ctaPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('No workers yet - add the first one'), findsOneWidget);
      expect(find.text('Add Worker'), findsOneWidget);

      await tester.tap(find.text('Add Worker'));
      await tester.pump();

      expect(ctaPressed, isTrue);
    });

    testWidgets('ErrorView displays message and triggers retry', (tester) async {
      var retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Failed to load entries',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to load entries'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryPressed, isTrue);
    });
  });

  group('QuantityStepper Widget Tests', () {
    testWidgets('displays initial value and unit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 10,
              min: 0,
              max: 20,
              unit: 'bags',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('bags'), findsOneWidget);
    });

    testWidgets('increments value on plus button tap', (tester) async {
      double? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 5,
              min: 0,
              max: 10,
              unit: 'bags',
              onChanged: (v) => updated = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('stepper_increment_button')));
      await tester.pump();

      expect(updated, 6.0);
    });

    testWidgets('decrements value on minus button tap', (tester) async {
      double? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 5,
              min: 0,
              max: 10,
              unit: 'bags',
              onChanged: (v) => updated = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('stepper_decrement_button')));
      await tester.pump();

      expect(updated, 4.0);
    });

    testWidgets('cannot decrement below min (minus button disabled)', (tester) async {
      double? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 0,
              min: 0,
              max: 10,
              unit: 'bags',
              onChanged: (v) => updated = v,
            ),
          ),
        ),
      );

      final minusButton = tester.widget<FilledButton>(
        find.byKey(const Key('stepper_decrement_button')),
      );
      expect(minusButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('stepper_decrement_button')));
      await tester.pump();

      expect(updated, isNull);
    });

    testWidgets('cannot increment above max (plus button disabled)', (tester) async {
      double? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuantityStepper(
              value: 10,
              min: 0,
              max: 10,
              unit: 'bags',
              onChanged: (v) => updated = v,
            ),
          ),
        ),
      );

      final plusButton = tester.widget<FilledButton>(
        find.byKey(const Key('stepper_increment_button')),
      );
      expect(plusButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('stepper_increment_button')));
      await tester.pump();

      expect(updated, isNull);
    });
  });

  group('SeveritySelector Widget Tests', () {
    testWidgets('renders all 4 severity levels and triggers onChanged', (tester) async {
      Severity? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeveritySelector(
              value: Severity.minor,
              onChanged: (s) => selected = s,
            ),
          ),
        ),
      );

      expect(find.text('Minor'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);

      await tester.tap(find.byKey(const Key('severity_critical')));
      await tester.pump();

      expect(selected, Severity.critical);
    });
  });

  group('AttendanceToggle Widget Tests', () {
    testWidgets('renders Present, Half-day, Absent and selects status on tap', (tester) async {
      AttendanceStatus? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceToggle(
              value: AttendanceStatus.present,
              onChanged: (status) => selected = status,
            ),
          ),
        ),
      );

      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Half-day'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);

      await tester.tap(find.byKey(const Key('attendance_toggle_half')));
      await tester.pump();

      expect(selected, AttendanceStatus.half);

      await tester.tap(find.byKey(const Key('attendance_toggle_absent')));
      await tester.pump();

      expect(selected, AttendanceStatus.absent);
    });
  });
}
