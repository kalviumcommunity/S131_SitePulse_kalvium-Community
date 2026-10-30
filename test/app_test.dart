import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/app.dart';

void main() {
  testWidgets('app scroll behavior omits overscroll indicators', (
    tester,
  ) async {
    const behavior = SitePulseScrollBehavior();
    final child = Container();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              identical(
                child,
                behavior.buildOverscrollIndicator(
                  context,
                  child,
                  const ScrollableDetails(direction: AxisDirection.down),
                ),
              ),
              isTrue,
            );
            expect(
              behavior.getScrollPhysics(context),
              isA<ClampingScrollPhysics>(),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
