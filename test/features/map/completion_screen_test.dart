import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_states/core/ads/ad_service.dart';
import 'package:state_states/core/ads/ad_service_provider.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/map/completion_screen.dart';

/// Spy ad service that records calls — for AD-04 test.
class _SpyAdService implements AdService {
  int interstitialCallCount = 0;

  @override
  Widget getBannerWidget() => const SizedBox.shrink();

  @override
  Future<void> showInterstitialAd() async {
    interstitialCallCount++;
  }

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  Future<void> showAppOpenAd() async {}
}

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

Widget buildScreen(GameSession session, {int? previousBest, AdService? adService}) {
  final widget = MaterialApp(
    home: CompletionScreen(session: session, previousBest: previousBest),
  );
  if (adService != null) {
    return ProviderScope(
      overrides: [
        adServiceProvider.overrideWithValue(adService),
      ],
      child: widget,
    );
  }
  // No ProviderScope — existing tests don't use ref yet.
  return widget;
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

    // AD-04: CompletionScreen fires showInterstitialAd() after 1-second delay.
    testWidgets(
        'AD-04: showInterstitialAd called once after 1-second delay on mount',
        (tester) async {
      final spy = _SpyAdService();
      final session = makeSession();
      await tester.pumpWidget(buildScreen(session, previousBest: null, adService: spy));
      await tester.pump(); // initState fires; Future.delayed starts

      // No call before 1 second elapses.
      expect(spy.interstitialCallCount, equals(0));

      // Advance time by 1.1 seconds — Future.delayed fires.
      await tester.pump(const Duration(milliseconds: 1100));

      expect(spy.interstitialCallCount, equals(1),
          reason: 'AD-04: showInterstitialAd must be called once after 1s delay');
    });
  });

  // -------------------------------------------------------------------------
  // Phase 7 gated sharing
  // SHARE-01: Share button is only shown when _isNewPb == true.
  // SHARE-04: Math gate uses multiplication (_a * _b); only a grown-up can pass.
  // -------------------------------------------------------------------------
  group('Phase 7 gated sharing', () {
    // -----------------------------------------------------------------------
    // SHARE-01 visibility tests
    // -----------------------------------------------------------------------

    // Wave 0 status: FAILS — current code shows Share button unconditionally
    // so findsNothing assertion fails.  RED until Plan 02 gates button on _isNewPb.
    testWidgets('SHARE-01: Share button absent when score > previousBest (non-PB)',
        (tester) async {
      // score=125 > previousBest=100 → _isNewPb == false
      final session = makeSession(score: 125);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      expect(find.text('Share result'), findsNothing);
    });

    // Wave 0 status: PASSES — current code shows Share button unconditionally
    // so findsOneWidget succeeds.  This test turns RED if the button is ever
    // removed entirely, providing regression protection.
    testWidgets('SHARE-01: Share button present when score < previousBest (PB)',
        (tester) async {
      // score=50 < previousBest=100 → _isNewPb == true
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      expect(find.text('Share result'), findsOneWidget);
    });

    // Wave 0 status: FAILS — current code shows Share button unconditionally
    // so findsNothing assertion fails.  RED until Plan 02 gates button on _isNewPb.
    testWidgets('SHARE-01: Share button absent when previousBest is null (first game)',
        (tester) async {
      // previousBest == null → _isNewPb == false (no baseline to beat)
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: null));
      await tester.pump();

      expect(find.text('Share result'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // SHARE-04 dialog behavior tests
    //
    // These tests open the math-challenge dialog by tapping the Share result
    // button on a PB CompletionScreen (score=50, previousBest=100).
    //
    // SHARE-04: RED until Plan 02 upgrades MathChallengeDialog from addition
    // to multiplication.
    // Test 3 passes when _a * _b is checked; currently _a + _b is checked so
    // supplying the product will give an incorrect answer and the dialog will
    // not dismiss — making this test FAIL at Wave 0.
    // -----------------------------------------------------------------------

    // Wave 0 status: FAILS — dialog currently shows 'What is N + M?' (addition).
    // find.textContaining('What is') will match, but parse attempts using the
    // multiplication RegExp ('What is (\d+) × (\d+)') will find no match because
    // the question uses '+' not '×'.  The assertion that the dialog is dismissed
    // after supplying the product will therefore FAIL.
    // RED until Plan 02 changes the dialog question to multiplication format.
    testWidgets(
        // ignore: lines_longer_than_80_chars
        'SHARE-04: correct multiplication answer (a * b) dismisses dialog with true',
        (tester) async {
      // SHARE-04: RED until Plan 02 upgrades MathChallengeDialog from addition to multiplication.
      // Test 3 passes when _a * _b is checked; currently _a + _b will give wrong result for parsed operands.
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      // Scroll to make Share result button visible before tapping.
      await tester.ensureVisible(find.text('Share result'));
      await tester.pump();

      // Open the math-challenge dialog via the Share result button.
      await tester.tap(find.text('Share result'));
      await tester.pumpAndSettle();

      // Dialog must be open.
      expect(find.byType(AlertDialog), findsOneWidget);

      // Locate the question text.  After Plan 02 it reads 'What is A × B?'.
      // The × character is Unicode U+00D7.  At Wave 0 the question uses '+',
      // so the RegExp below finds no match and the product cannot be computed —
      // this is the intended RED failure path.
      final questionFinder = find.textContaining('What is');
      expect(questionFinder, findsOneWidget);
      final questionText =
          (tester.widget<Text>(questionFinder)).data ?? '';

      final multiplyRegExp = RegExp(r'What is (\d+) × (\d+)');
      final match = multiplyRegExp.firstMatch(questionText);
      // RED at Wave 0: match is null because question uses '+', not '×'.
      // This expect fails at Wave 0, producing the expected RED failure.
      expect(match, isNotNull,
          reason:
              'Dialog question must use multiplication (×) format — RED until Plan 02');

      if (match != null) {
        final a = int.parse(match.group(1)!);
        final b = int.parse(match.group(2)!);
        final product = a * b;

        await tester.enterText(find.byType(TextField), '$product');
        await tester.pump();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Share'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed after correct answer.
        expect(find.byType(AlertDialog), findsNothing);
      }
    });

    // Wave 0 status: depends on current dialog state; may pass or fail.
    // Entering '9999' is guaranteed wrong for any 2-digit × 1-digit problem
    // (max 99 × 9 = 891) AND any 2-digit + 1-digit problem (max 9 + 9 = 18),
    // so the error message should appear in both cases.
    testWidgets(
        'SHARE-04: wrong answer keeps dialog open and shows error',
        (tester) async {
      // SHARE-04: RED until Plan 02 upgrades MathChallengeDialog from addition to multiplication.
      // Test 3 passes when _a * _b is checked; currently _a + _b will give wrong result for parsed operands.
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      // Scroll to make Share result button visible before tapping.
      await tester.ensureVisible(find.text('Share result'));
      await tester.pump();

      // Open the dialog.
      await tester.tap(find.text('Share result'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter a value guaranteed to be wrong (9999 exceeds any possible answer).
      await tester.enterText(find.byType(TextField), '9999');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Share'));
      await tester.pump();

      // Error message should be visible; dialog must still be present.
      expect(find.text('Incorrect — try again'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    // Wave 0 status: depends on current dialog state; may pass or fail.
    testWidgets('SHARE-04: Cancel dismisses dialog and returns false',
        (tester) async {
      // SHARE-04: RED until Plan 02 upgrades MathChallengeDialog from addition to multiplication.
      // Test 3 passes when _a * _b is checked; currently _a + _b will give wrong result for parsed operands.
      final session = makeSession(score: 50);
      await tester.pumpWidget(buildScreen(session, previousBest: 100));
      await tester.pump();

      // Scroll to make Share result button visible before tapping.
      await tester.ensureVisible(find.text('Share result'));
      await tester.pump();

      // Open the dialog.
      await tester.tap(find.text('Share result'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap Cancel — dialog should be dismissed.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
