import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/pressable_scale.dart';

/// Finds the current scale of the first [PressableScale] in the tree.
double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(PressableScale),
          matching: find.byType(Transform),
        )
        .first,
  );
  final matrix = transform.transform;
  // `getMaxScaleOnAxis` reports the largest scale on any axis, which for a
  // 2D `Transform.scale` is the z scale (1.0). The x scale is the one that
  // drives the press feedback.
  return matrix.storage[0];
}

/// Hosts a [PressableScale] in the minimum scaffolding it needs.
Widget _host({
  required VoidCallback onPressed,
  bool enabled = true,
  double pressedScale = 0.96,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: PressableScale(
          onPressed: enabled ? onPressed : null,
          pressedScale: pressedScale,
          child: const SizedBox(
            width: 60,
            height: 60,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the scale drops on pointer down, before the tap completes',
      (tester) async {
    var fired = false;
    await tester.pumpWidget(_host(onPressed: () => fired = true));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(_scaleOf(tester), lessThan(0.98));
    expect(fired, isFalse, reason: 'The action must not fire on pointer down');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(fired, isTrue);
  });

  testWidgets('the scale springs back after the release', (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_scaleOf(tester), closeTo(1.0, 0.001));
  });

  testWidgets('a double tap within the lock fires exactly once',
      (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(onPressed: () => fired++));

    await tester.tap(find.byType(PressableScale));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();

    expect(fired, 1, reason: 'The 150 ms lock must swallow the second tap');
  });

  testWidgets('a tap after the lock fires again', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(onPressed: () => fired++));

    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();

    expect(fired, 2);
  });

  testWidgets('dragging out of the target cancels the activation',
      (tester) async {
    var fired = false;
    await tester.pumpWidget(_host(onPressed: () => fired = true));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // Drag well outside the target.
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, isFalse, reason: 'Dragging out must cancel the activation');
  });

  testWidgets('a disabled target does nothing', (tester) async {
    var fired = false;
    await tester.pumpWidget(_host(onPressed: () => fired = true, enabled: false));

    await tester.tap(find.byType(PressableScale));
    await tester.pumpAndSettle();

    expect(fired, isFalse);
  });

  testWidgets('the minimum target is 48 dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onPressed: () {},
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(PressableScale));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the launcher shrinks further than everything else',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onPressed: () {},
              pressedScale: 0.94,
              child: const SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_scaleOf(tester), lessThan(0.96));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('no tickers are left running after the gesture',
      (tester) async {
    await tester.pumpWidget(_host(onPressed: () {}));

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
