import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/data/state_data_service.dart';
import 'package:state_states/features/game/game_hud.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_session_notifier.dart';
import 'package:state_states/features/map/map_screen.dart';
import 'package:state_states/features/map/usa_map_painter.dart';

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

  // ---------------------------------------------------------------------------
  // Mode → showLabels matrix tests
  // ---------------------------------------------------------------------------

  group('MapScreen mode visibility', () {
    Future<void> pumpWithMode(
      WidgetTester tester,
      MapData mapData,
      GameMode mode,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stateDataProvider.overrideWith((ref) async => mapData),
          ],
          child: MaterialApp(home: MapScreen(mode: mode)),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'Learn mode passes showLabels: true to UsaMapPainter',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mapData =
            await tester.runAsync(() => container.read(stateDataProvider.future));
        expect(mapData, isNotNull);

        await pumpWithMode(tester, mapData!, GameMode.learn);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is UsaMapPainter &&
                (w.painter! as UsaMapPainter).showLabels == true,
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'StatesMaster mode passes showLabels: false to UsaMapPainter',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mapData =
            await tester.runAsync(() => container.read(stateDataProvider.future));
        expect(mapData, isNotNull);

        await pumpWithMode(tester, mapData!, GameMode.statesMaster);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is UsaMapPainter &&
                (w.painter! as UsaMapPainter).showLabels == false,
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'GeographicalMaster mode passes showLabels: true to UsaMapPainter',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mapData =
            await tester.runAsync(() => container.read(stateDataProvider.future));
        expect(mapData, isNotNull);

        await pumpWithMode(tester, mapData!, GameMode.geographicalMaster);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is UsaMapPainter &&
                (w.painter! as UsaMapPainter).showLabels == true,
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'GrandMaster mode passes showLabels: false to UsaMapPainter',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mapData =
            await tester.runAsync(() => container.read(stateDataProvider.future));
        expect(mapData, isNotNull);

        await pumpWithMode(tester, mapData!, GameMode.grandMaster);

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is UsaMapPainter &&
                (w.painter! as UsaMapPainter).showLabels == false,
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // DragTarget and PopScope presence tests
  // ---------------------------------------------------------------------------

  testWidgets(
    'MapScreen has DragTarget for drop handling',
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

      expect(find.byType(DragTarget<String>), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'MapScreen has PopScope back-button guard',
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

      // find.byType(PopScope) matches PopScope<dynamic> but the tree has
      // PopScope<Object?> — use a widgetPredicate to match any PopScope.
      expect(
        find.byWidgetPredicate((w) => w is PopScope),
        findsAtLeastNWidgets(1),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Plan 04 tests: GameHud and StateTray AnimatedSwitcher
  // ---------------------------------------------------------------------------

  testWidgets(
    'MapScreen shows GameHud in game layout',
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

      expect(find.byType(GameHud), findsOneWidget);
    },
  );

  testWidgets(
    'MapScreen shows StateTray AnimatedSwitcher area',
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

      expect(find.byType(AnimatedSwitcher), findsAtLeastNWidgets(1));
    },
  );

  // ---------------------------------------------------------------------------
  // Session restore test: _startSequence must seed _matchedPostals from the
  // restored session's matchedPostals before the first build.
  // ---------------------------------------------------------------------------

  testWidgets(
    'MapScreen restores session: HUD shows matchedCount=2 and painter has CA+TX matched',
    (tester) async {
      // Step 1: resolve real map data outside FakeAsync.
      final dataContainer = ProviderContainer();
      addTearDown(dataContainer.dispose);
      final mapData = await tester
          .runAsync(() => dataContainer.read(stateDataProvider.future));
      expect(mapData, isNotNull);

      // Step 2: create a container pre-seeded with a paused restored session.
      // Override stateDataProvider so MapScreen gets data immediately and
      // gameSessionProvider starts in a paused/restored state with CA+TX matched.
      final restoredSession = const GameSession(
        phase: GamePhase.paused,
        mode: GameMode.learn,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
        matchedPostals: ['CA', 'TX'],
      );

      final gameContainer = ProviderContainer(
        overrides: [
          stateDataProvider.overrideWith((ref) async => mapData!),
        ],
      );
      addTearDown(gameContainer.dispose);

      // Wait for gameSessionProvider to resolve (it's an AsyncNotifier).
      await tester.runAsync(
          () => gameContainer.read(gameSessionProvider.future));

      // Seed the session before the first build so _startSequence sees it.
      gameContainer.read(gameSessionProvider.notifier).restoreGame(
            restoredSession,
            hintPenalty: 0,
          );

      // Step 3: pump using UncontrolledProviderScope so the pre-seeded container
      // is used as-is (no fresh build() call that would reset the session).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: gameContainer,
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      // Two pumps: first emits data, second fires postFrameCallback rebuilds.
      await tester.pump();
      await tester.pump();

      // Assert 1: GameHud shows matchedCount == 2.
      final hud = tester.widget<GameHud>(find.byType(GameHud));
      expect(hud.matchedCount, equals(2),
          reason: 'HUD should report 2 matched states from restored session');

      // Assert 2: UsaMapPainter received CA and TX as matched.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is UsaMapPainter &&
              (w.painter! as UsaMapPainter)
                  .matchedPostals
                  .containsAll({'CA', 'TX'}),
        ),
        findsAtLeastNWidgets(1),
        reason: 'UsaMapPainter must receive CA and TX as matched postals',
      );
    },
  );
}
