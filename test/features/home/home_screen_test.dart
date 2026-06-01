import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/home/home_screen.dart';
import 'package:state_states/features/home/session_restore_card.dart';

class MockHighScoreRepository extends Mock implements HighScoreRepository {}

class MockGameStateRepository extends Mock implements GameStateRepository {}

Widget buildHomeScreen(
  MockHighScoreRepository mockRepo, {
  MockGameStateRepository? mockGameStateRepo,
}) {
  return ProviderScope(
    overrides: [
      highScoreRepositoryProvider.overrideWith((_) async => mockRepo),
      if (mockGameStateRepo != null)
        gameStateRepositoryProvider.overrideWith(
          (_) async => mockGameStateRepo,
        ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  setUpAll(() {
    // Register fallback for GameMode so mocktail any() works.
    registerFallbackValue(GameMode.learn);
    // Register fallback for GameSession so mocktail any() works.
    registerFallbackValue(
      const GameSession(
        phase: GamePhase.playing,
        mode: GameMode.learn,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        hintsRemaining: 2,
      ),
    );
  });

  group('HomeScreen mode cards', () {
    testWidgets('shows 4 mode cards with correct names', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump(); // let FutureProvider emit
      await tester.pump(); // let FutureBuilder resolve

      expect(find.text('Learn'), findsAtLeastNWidgets(1));
      expect(find.text('States Master'), findsAtLeastNWidgets(1));
      expect(find.text('Geographical Master'), findsAtLeastNWidgets(1));
      expect(find.text('Grand Master'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Not played when no score stored', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Not played'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Best: N when score available', (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(GameMode.learn))
          .thenAnswer((_) async => 50);
      when(() => mockRepo.getBestScore(GameMode.statesMaster))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getBestScore(GameMode.geographicalMaster))
          .thenAnswer((_) async => null);
      when(() => mockRepo.getBestScore(GameMode.grandMaster))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(buildHomeScreen(mockRepo));
      await tester.pump();
      await tester.pump();

      expect(find.text('Best: 50'), findsOneWidget);
      // Other 3 modes have no score
      expect(find.text('Not played'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders without crashing in loading state', (tester) async {
      // Use a future that never completes to keep provider in loading state.
      final completer = Completer<HighScoreRepository>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            highScoreRepositoryProvider
                .overrideWith((_) => completer.future),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump(); // one pump — provider still loading

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up: complete the future so the Completer is not leaked.
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);
      completer.complete(mockRepo);
    });
  });

  // ---------------------------------------------------------------------------
  // SessionRestoreCard unit tests
  // ---------------------------------------------------------------------------

  group('SessionRestoreCard widget', () {
    const testSession = GameSession(
      phase: GamePhase.paused,
      mode: GameMode.learn,
      score: 42,
      elapsed: Duration(seconds: 90),
      errorCount: 2,
      hintsRemaining: 1,
      matchedPostals: ['TX', 'CA', 'NY'],
    );

    testWidgets('Test 1: shows mode label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRestoreCard(
              session: testSession,
              hintPenalty: 0,
              onContinue: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Learn'), findsAtLeastNWidgets(1));
    });

    testWidgets('Test 2: shows elapsed time in MM:SS format', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRestoreCard(
              session: testSession,
              hintPenalty: 0,
              onContinue: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      // 90 seconds = 01:30
      expect(find.textContaining('01:30'), findsAtLeastNWidgets(1));
    });

    testWidgets('Test 3: shows states placed count (e.g. "3 / 50")',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRestoreCard(
              session: testSession,
              hintPenalty: 0,
              onContinue: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('3 / 50'), findsAtLeastNWidgets(1));
    });

    testWidgets('Test 4: tapping Continue button calls onContinue callback',
        (tester) async {
      var continueCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRestoreCard(
              session: testSession,
              hintPenalty: 0,
              onContinue: () => continueCalled = true,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      expect(continueCalled, isTrue);
    });

    testWidgets('Test 5: tapping Dismiss button calls onDismiss callback',
        (tester) async {
      var dismissCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRestoreCard(
              session: testSession,
              hintPenalty: 0,
              onContinue: () {},
              onDismiss: () => dismissCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Dismiss'));
      expect(dismissCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // HOME-03: Session restore card integration tests
  // ---------------------------------------------------------------------------

  group('HomeScreen session restore (HOME-03)', () {
    const savedSession = GameSession(
      phase: GamePhase.paused,
      mode: GameMode.learn,
      score: 42,
      elapsed: Duration(seconds: 90),
      errorCount: 2,
      hintsRemaining: 1,
      matchedPostals: [
        'TX', 'CA', 'NY', 'FL', 'IL', 'PA', 'OH', 'GA', 'NC', 'MI',
        'NJ', 'VA', 'WA', 'AZ', 'MA', 'TN', 'IN', 'MO', 'MD', 'WI',
        'CO', 'MN', 'SC',
      ],
    );

    testWidgets(
        'Test 1 (HOME-03 shown): shows CONTINUE when session exists',
        (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      final mockGameStateRepo = MockGameStateRepository();
      when(() => mockGameStateRepo.loadSession()).thenAnswer(
        (_) async => (session: savedSession, hintPenalty: 0),
      );

      await tester.pumpWidget(
        buildHomeScreen(mockRepo, mockGameStateRepo: mockGameStateRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsOneWidget);
    });

    testWidgets(
        'Test 2 (HOME-03 hidden): hides CONTINUE when no session exists',
        (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      final mockGameStateRepo = MockGameStateRepository();
      when(() => mockGameStateRepo.loadSession())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildHomeScreen(mockRepo, mockGameStateRepo: mockGameStateRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONTINUE'), findsNothing);
    });

    testWidgets('Test 3: existing mode card tests still pass (no regression)',
        (tester) async {
      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      final mockGameStateRepo = MockGameStateRepository();
      when(() => mockGameStateRepo.loadSession())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildHomeScreen(mockRepo, mockGameStateRepo: mockGameStateRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Learn'), findsAtLeastNWidgets(1));
      expect(find.text('States Master'), findsAtLeastNWidgets(1));
      expect(find.text('Geographical Master'), findsAtLeastNWidgets(1));
      expect(find.text('Grand Master'), findsAtLeastNWidgets(1));
    });
  });

  // ---------------------------------------------------------------------------
  // A11Y: Tap target guideline tests (A11Y-01)
  // ---------------------------------------------------------------------------

  group('HomeScreen A11Y', () {
    testWidgets(
        'Test 1 (A11Y-01): meets androidTapTargetGuideline — all interactive '
        'controls are at least 48×48dp', (tester) async {
      final handle = tester.ensureSemantics();

      final mockRepo = MockHighScoreRepository();
      when(() => mockRepo.getBestScore(any())).thenAnswer((_) async => null);

      final mockGameStateRepo = MockGameStateRepository();
      when(() => mockGameStateRepo.loadSession())
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildHomeScreen(mockRepo, mockGameStateRepo: mockGameStateRepo),
      );
      await tester.pump();
      await tester.pump();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      handle.dispose();
    });
  });
}
