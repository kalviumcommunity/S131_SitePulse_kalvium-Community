import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/app.dart';

import 'support/test_overrides.dart';

void main() {
  testWidgets('SitePulseApp renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(),
        child: SitePulseApp(firebaseReady: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SitePulseApp), findsOneWidget);
  });
}
