import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/features/map/usa_map_painter.dart';

void main() {
  // rootBundle asset access + compute() require an initialized binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load MapData once for the two smoke tests that need real geometry.
  // Uses tester.runAsync() to escape FakeAsync — compute() spawns a real isolate
  // and cannot resolve inside FakeAsync's microtask-only event loop.
  testWidgets('UsaMapPainter renders all 51 states without exception',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // tester.runAsync lets real async work (isolate spawning) complete.
    final mapData =
        await tester.runAsync(() => container.read(stateDataProvider.future));
    expect(mapData, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1000,
          height: 628,
          child: CustomPaint(
            isComplex: true,
            painter: UsaMapPainter(
              states: mapData!.states,
              matchedPostals: const {},
              insetFrameRects: mapData.insetFrameRects,
              viewScale: 1.0,
            ),
            size: const Size(1000, 628),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'UsaMapPainter renders matched state in grey without exception',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mapData =
        await tester.runAsync(() => container.read(stateDataProvider.future));
    expect(mapData, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1000,
          height: 628,
          child: CustomPaint(
            isComplex: true,
            painter: UsaMapPainter(
              states: mapData!.states,
              matchedPostals: const {'TX'},
              insetFrameRects: mapData.insetFrameRects,
              viewScale: 1.0,
            ),
            size: const Size(1000, 628),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  test('shouldRepaint returns false for identical parameters', () {
    const painter = UsaMapPainter(
      states: [],
      matchedPostals: {},
      insetFrameRects: [],
      viewScale: 1.0,
    );
    const same = UsaMapPainter(
      states: [],
      matchedPostals: {},
      insetFrameRects: [],
      viewScale: 1.0,
    );

    expect(painter.shouldRepaint(same), isFalse);
  });

  test('shouldRepaint returns true when matchedPostals changes', () {
    const painter1 = UsaMapPainter(
      states: [],
      matchedPostals: {},
      insetFrameRects: [],
      viewScale: 1.0,
    );
    const painter2 = UsaMapPainter(
      states: [],
      matchedPostals: {'TX'},
      insetFrameRects: [],
      viewScale: 1.0,
    );

    expect(painter2.shouldRepaint(painter1), isTrue);
  });
}
