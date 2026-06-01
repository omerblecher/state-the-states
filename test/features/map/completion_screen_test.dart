import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/map/completion_screen.dart';

GameSession makeSession({int score = 100, GameMode mode = GameMode.learn}) {
  return GameSession(
    phase: GamePhase.completed,
    mode: mode,
    score: score,
    elapsed: const Duration(minutes: 2, seconds: 34),
    errorCount: 0,
    hintsRemaining: 2,
    matchedPostals: const [],
  );
}

Widget buildScreen(GameSession session, {int? previousBest}) {
  return MaterialApp(
    home: CompletionScreen(session: session, previousBest: previousBest),
  );
}

void main() {
  group('computeStarCount', () {
    test('returns 3 for first game (previousBest == null)', () {
      expect(computeStarCount(100, null), equals(3));
    });
    test('returns 3 for personal best', () {
      expect(computeStarCount(50, 100), equals(3));
    });
    test('returns 2 for score within 20% of best', () {
      // 115 <= ceil(100 * 1.20) = 120
      expect(computeStarCount(115, 100), equals(2));
    });
    test('returns 1 for score more than 20% above best', () {
      // 125 > 120
      expect(computeStarCount(125, 100), equals(1));
    });
  });

  group('CompletionScreen widget tests', () {
    testWidgets('first game shows 3 filled stars and no PB badge',
        (tester) async {
      final session = makeSession();
      await tester.pumpWidget(buildScreen(session, previousBest: null));
      await tester.pump();

      // 3 filled stars
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      // No PB badge
      expect(find.text('New Personal Best!'), findsNothing);
    });

    testWidgets('personal best shows 3 filled stars and PB badge',
        (tester) async {
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      // 3 filled stars
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      // PB badge visible
      expect(find.text('New Personal Best!'), findsOneWidget);
    });

    testWidgets('2 stars when within 20% of best', (tester) async {
      final session = makeSession(score: 115);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));
      expect(find.text('New Personal Best!'), findsNothing);
    });

    testWidgets('1 star when beyond 20% of best', (tester) async {
      final session = makeSession(score: 125);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(1));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('shows score in score card', (tester) async {
      final session = makeSession(score: 42);
      await tester.pumpWidget(buildScreen(session, previousBest: null));
      await tester.pump();

      expect(find.text('42'), findsAtLeastNWidgets(1));
    });

    testWidgets('Back to Menu button present', (tester) async {
      final session = makeSession();
      await tester.pumpWidget(buildScreen(session, previousBest: null));
      await tester.pump();

      expect(find.text('Back to Menu'), findsOneWidget);
    });

    testWidgets('Play Again button present', (tester) async {
      final session = makeSession();
      await tester.pumpWidget(buildScreen(session, previousBest: null));
      await tester.pump();

      expect(find.text('Play Again'), findsOneWidget);
    });
  });
}
