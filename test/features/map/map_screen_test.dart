import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/features/map/map_screen.dart';

void main() {
  // rootBundle asset access + compute() require an initialized binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helper: resolve real MapData via a ProviderContainer before widget tests.
  // tester.runAsync() is required because stateDataProvider uses compute()
  // (a real isolate). FakeAsync blocks isolate completion.
  // ---------------------------------------------------------------------------

  testWidgets(
    'MapScreen renders without exception with real stateDataProvider',
    (tester) async {
      // Resolve data outside FakeAsync first.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mapData =
          await tester.runAsync(() => container.read(stateDataProvider.future));
      expect(mapData, isNotNull);

      // Override with already-resolved data to avoid FakeAsync / isolate issues.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData!),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      // Two pumps: first lets the FutureProvider emit data, second lets
      // postFrameCallback fire and rebuilds the widget with the map stack.
      await tester.pump();
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    },
  );

  testWidgets(
    'zoom in button does not crash and InteractiveViewer stays visible',
    (tester) async {
      // Note: Precise scale assertion (getMaxScaleOnAxis() == entry(0,0) == entry(2,2))
      // is validated via SpikeMapScreen manual testing in Plan 05 where the controller
      // is directly observable via debugPrint output (Criterion 4 hard gate).
      // TODO(phase-3): Expose _controller via @visibleForTesting for precise scale
      // assertions once entry(2,2) sync is verified via SpikeMapScreen (Criterion 4).
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mapData =
          await tester.runAsync(() => container.read(stateDataProvider.future));
      expect(mapData, isNotNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData!),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Tap zoom in once.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Map must remain visible after zoom — no crash from _zoom().
      expect(find.byType(InteractiveViewer), findsOneWidget);
      // Loading indicator should be gone (data resolved).
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'zoom out button does not crash when pressed repeatedly at min scale',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mapData =
          await tester.runAsync(() => container.read(stateDataProvider.future));
      expect(mapData, isNotNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData!),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Tap zoom out 10 times — should clamp to minScale without crashing.
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();
      }

      // InteractiveViewer must still be present after repeated zoom out.
      expect(find.byType(InteractiveViewer), findsOneWidget);
    },
  );

  testWidgets(
    'MapScreen shows loading indicator before data resolves',
    (tester) async {
      // Use a Completer so the future never resolves during the test, and we
      // can control its lifetime without leaking timers.
      final completer = Completer<MapData>();

      final overrides = [
        stateDataProvider.overrideWith((ref) => completer.future),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      // pump() NOT pumpAndSettle — we want the loading state, not the settled state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future before widget disposal to avoid timer-pending assertions.
      completer.complete(MapData(states: const [], insetFrameRects: const []));
      await tester.pump();
    },
  );
}
