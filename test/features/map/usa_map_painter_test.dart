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

  group('hintPostal glow', () {
    test('shouldRepaint returns true when hintPostal changes from null to non-null',
        () {
      const painterNull = UsaMapPainter(
        states: [],
        matchedPostals: {},
        insetFrameRects: [],
        viewScale: 1.0,
        hintPostal: null,
      );
      const painterWithHint = UsaMapPainter(
        states: [],
        matchedPostals: {},
        insetFrameRects: [],
        viewScale: 1.0,
        hintPostal: 'TX',
      );

      // Glow start: null → 'TX' must trigger repaint (D-H3)
      expect(painterWithHint.shouldRepaint(painterNull), isTrue);

      // Glow end: 'TX' → null must trigger repaint (D-H3)
      expect(painterNull.shouldRepaint(painterWithHint), isTrue);
    });

    test('shouldRepaint returns false when hintPostal is unchanged', () {
      const painter1 = UsaMapPainter(
        states: [],
        matchedPostals: {},
        insetFrameRects: [],
        viewScale: 1.0,
        hintPostal: 'CA',
      );
      const painter2 = UsaMapPainter(
        states: [],
        matchedPostals: {},
        insetFrameRects: [],
        viewScale: 1.0,
        hintPostal: 'CA',
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    testWidgets(
        'UsaMapPainter with hintPostal renders without exception using real data',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mapData =
          await tester.runAsync(() => container.read(stateDataProvider.future));
      expect(mapData, isNotNull);

      // Verify TX is in the data (it always is in the full 51-record set).
      final txState =
          mapData!.states.where((s) => s.postal == 'TX').toList();
      expect(txState, isNotEmpty,
          reason: 'TX must be present in state data for hint glow test');

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1000,
            height: 628,
            child: CustomPaint(
              isComplex: true,
              painter: UsaMapPainter(
                states: mapData.states,
                matchedPostals: const {},
                insetFrameRects: mapData.insetFrameRects,
                viewScale: 1.0,
                hintPostal: 'TX', // hint glow active
              ),
              size: const Size(1000, 628),
            ),
          ),
        ),
      );

      // Painter renders without throwing; CustomPaint widget is present.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

      // The painter itself should have the hintPostal set.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is UsaMapPainter &&
              (w.painter! as UsaMapPainter).hintPostal == 'TX',
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
