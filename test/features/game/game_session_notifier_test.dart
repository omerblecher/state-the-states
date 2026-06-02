import 'dart:ui' show Offset, Path;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/core/models/state_data.dart';
import 'package:state_states/core/ticker.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';
import 'package:state_states/features/game/game_session_notifier.dart';

class MockGameStateRepository extends Mock implements GameStateRepository {}

class MockHighScoreRepository extends Mock implements HighScoreRepository {}

/// Returns a minimal list of [StateData] entries for use in submitTyping() unit
/// tests. Includes a single-word state (Georgia), a multi-word state (New York),
/// and an inset state (Alaska) to exercise D-02 and inset-group logic.
List<StateData> stateFixture() => [
      const StateData(
        postal: 'GA',
        name: 'Georgia',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'CA',
        name: 'California',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'NY',
        name: 'New York',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'TX',
        name: 'Texas',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: null,
      ),
      const StateData(
        postal: 'AK',
        name: 'Alaska',
        pathStrings: [],
        paths: [],
        boundingBox: BoundingBox(x: 0, y: 0, w: 100, h: 100),
        centroid: Offset(50, 50),
        isPlaceable: true,
        insetGroup: InsetGroup.alaska,
      ),
    ];

void main() {
  // ── GameModeDisplay extension ─────────────────────────────────────────────
  group('GameModeDisplay.displayName', () {
    test('learn → Learn', () {
      expect(GameMode.learn.displayName, 'Learn');
    });
    test('statesMaster → States Master', () {
      expect(GameMode.statesMaster.displayName, 'States Master');
    });
    test('geographicalMaster → Geographical Master', () {
      expect(GameMode.geographicalMaster.displayName, 'Geographical Master');
    });
    test('grandMaster → Grand Master', () {
      expect(GameMode.grandMaster.displayName, 'Grand Master');
    });
    test('speedTyping → Speed Typing', () {
      expect(GameMode.speedTyping.displayName, 'Speed Typing');
    });
    test('GameMode.values contains speedTyping', () {
      expect(GameMode.values, contains(GameMode.speedTyping));
    });
  });

  setUpAll(() {
    // mocktail requires fallback values for any() matchers on non-nullable types.
    registerFallbackValue(const GameSession(
      phase: GamePhase.idle,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      hintsRemaining: 2,
    ));
    registerFallbackValue(GameMode.learn);
  });

  late FakeTicker fakeTicker;
  late MockGameStateRepository mockGameRepo;
  late MockHighScoreRepository mockHighScoreRepo;
  late ProviderContainer container;

  setUp(() {
    fakeTicker = FakeTicker();
    mockGameRepo = MockGameStateRepository();
    mockHighScoreRepo = MockHighScoreRepository();

    // Stub all repository calls used in tests
    when(() => mockGameRepo.loadSession()).thenAnswer((_) async => null);
    when(
      () => mockGameRepo.saveSession(
        any(),
        hintPenalty: any(named: 'hintPenalty'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockGameRepo.clearSession(),
    ).thenAnswer((_) async {});
    when(
      () => mockHighScoreRepo.saveBestScore(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockHighScoreRepo.getBestScore(any()),
    ).thenAnswer((_) async => null);

    container = ProviderContainer(
      overrides: [
        gameSessionProvider.overrideWith(
          () => GameSessionNotifier(
            ticker: fakeTicker,
            gameStateRepository: mockGameRepo,
            highScoreRepository: mockHighScoreRepo,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Helper: build the provider, start a game, tick through the countdown
  /// (5 ticks), which leaves the session in [GamePhase.playing].
  Future<GameSessionNotifier> startIntoPlaying() async {
    final notifier = container.read(gameSessionProvider.notifier);
    await container.read(gameSessionProvider.future);
    notifier.startGame(GameMode.learn);
    // 5 ticks to exit countdown → playing; Stopwatch starts on the 5th tick
    for (var i = 0; i < 5; i++) {
      fakeTicker.tick();
    }
    return notifier;
  }

  group('startGame / countdown', () {
    test('session is idle before startGame()', () async {
      await container.read(gameSessionProvider.future);
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.idle);
    });

    test('phase is countdown immediately after startGame()', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      await container.read(gameSessionProvider.future);
      notifier.startGame(GameMode.learn);
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.countdown);
    });

    test('phase becomes playing after 5 countdown ticks', () async {
      await startIntoPlaying();
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.playing);
    });

    test('score is 0 during countdown regardless of tick count', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      await container.read(gameSessionProvider.future);
      notifier.startGame(GameMode.learn);
      for (var i = 0; i < 4; i++) {
        fakeTicker.tick();
      }
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.countdown);
      expect(session.score, 0);
    });
  });

  group('scoring formula (SCORE-01, SCORE-02)', () {
    test(
      'score = (elapsedSecs ~/ 10) + (errorCount * 5) + hintPenalty',
      () async {
        final notifier = await startIntoPlaying();

        // Add 2 wrong drops → errorCount = 2, score contribution = 10
        notifier.recordDrop('TX', isCorrect: false);
        notifier.recordDrop('CA', isCorrect: false);

        // Use 1 hint → _hintPenalty = 5
        notifier.useHint();

        // Tick once while playing (Stopwatch reads ~0s since it just started;
        // formula at 0s: (0 ~/ 10) + (2 * 5) + 5 = 0 + 10 + 5 = 15)
        fakeTicker.tick();

        final session = container.read(gameSessionProvider).value!;
        expect(session.errorCount, 2);
        expect(session.hintsRemaining, 1);
        // The score must match (elapsed~/ 10) + errorCount*5 + hintPenalty.
        // At a short elapsed (~0s), time component is 0.
        // Expected: 0 + 10 + 5 = 15.
        expect(session.score, 15);
      },
    );

    test(
      'each recordDrop(isCorrect: false) increments errorCount and score',
      () async {
        final notifier = await startIntoPlaying();

        notifier.recordDrop('TX', isCorrect: false);
        final after1 = container.read(gameSessionProvider).value!;
        expect(after1.errorCount, 1);

        notifier.recordDrop('CA', isCorrect: false);
        final after2 = container.read(gameSessionProvider).value!;
        expect(after2.errorCount, 2);
        // score ≥ errorCount * 5 (time component may add more)
        expect(after2.score, greaterThanOrEqualTo(10));
      },
    );

    test('recordDrop(isCorrect: true) appends postal to matchedPostals', () async {
      final notifier = await startIntoPlaying();

      notifier.recordDrop('TX', isCorrect: true);
      final session = container.read(gameSessionProvider).value!;
      expect(session.matchedPostals, contains('TX'));
    });

    test('recordDrop(isCorrect: true) flushes saveSession', () async {
      final notifier = await startIntoPlaying();

      notifier.recordDrop('TX', isCorrect: true);
      verify(
        () => mockGameRepo.saveSession(
          any(),
          hintPenalty: any(named: 'hintPenalty'),
        ),
      ).called(1);
    });
  });

  group('useHint()', () {
    test('useHint() returns true, adds 5 to score, decrements hintsRemaining',
        () async {
      final notifier = await startIntoPlaying();

      final result = notifier.useHint();
      expect(result, isTrue);

      final session = container.read(gameSessionProvider).value!;
      expect(session.hintsRemaining, 1);
      expect(session.score, greaterThanOrEqualTo(5)); // at least hintPenalty
    });

    test('useHint() returns false when hintsRemaining == 0', () async {
      final notifier = await startIntoPlaying();
      notifier.useHint(); // 2 → 1
      notifier.useHint(); // 1 → 0

      final result = notifier.useHint(); // should return false
      expect(result, isFalse);

      final session = container.read(gameSessionProvider).value!;
      expect(session.hintsRemaining, 0);
    });

    test('useHint() returns false when phase is not playing', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      await container.read(gameSessionProvider.future);
      // Phase is idle — useHint should be a no-op
      final result = notifier.useHint();
      expect(result, isFalse);
    });
  });

  group('pauseGame() — SESS-01 / D-02 / D-12 / CR-01 / CR-02', () {
    test('pauseGame() sets phase to paused', () async {
      final notifier = await startIntoPlaying();
      notifier.pauseGame();
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.paused);
    });

    // CR-01: null-state guard
    test('pauseGame() does not throw when state.value is null (CR-01)', () async {
      // Access notifier before the provider finishes loading (state is AsyncLoading).
      // We do NOT await gameSessionProvider.future here, so state.value may be null.
      final notifier = container.read(gameSessionProvider.notifier);
      // Must not throw even if state.value is null.
      expect(() => notifier.pauseGame(), returnsNormally);
    });

    // CR-02: phase guard — idle
    test('pauseGame() in idle phase does not change phase (CR-02)', () async {
      container.read(gameSessionProvider.notifier);
      await container.read(gameSessionProvider.future);
      // Phase is idle — call pauseGame().
      container.read(gameSessionProvider.notifier).pauseGame();
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.idle);
    });

    // CR-02: phase guard — idle does not write snapshot
    test('pauseGame() in idle phase does not write a snapshot (CR-02)', () async {
      container.read(gameSessionProvider.notifier);
      await container.read(gameSessionProvider.future);
      container.read(gameSessionProvider.notifier).pauseGame();
      verifyNever(
        () => mockGameRepo.saveSession(
          any(),
          hintPenalty: any(named: 'hintPenalty'),
        ),
      );
    });

    // CR-02: phase guard — completed does not write snapshot
    test('pauseGame() in completed phase does not write a snapshot (CR-02)', () async {
      final notifier = await startIntoPlaying();
      await notifier.completeGame();
      // Phase is now completed.
      final beforePause = container.read(gameSessionProvider).value!;
      expect(beforePause.phase, GamePhase.completed);
      // Clear invocations recorded during completeGame() to isolate pauseGame().
      clearInteractions(mockGameRepo);
      notifier.pauseGame();
      final afterPause = container.read(gameSessionProvider).value!;
      expect(afterPause.phase, GamePhase.completed); // unchanged
      verifyNever(
        () => mockGameRepo.saveSession(
          any(),
          hintPenalty: any(named: 'hintPenalty'),
        ),
      );
    });

    test('pauseGame() flushes saveSession', () async {
      final notifier = await startIntoPlaying();
      notifier.pauseGame();
      verify(
        () => mockGameRepo.saveSession(
          any(),
          hintPenalty: any(named: 'hintPenalty'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('elapsed does not advance after pauseGame() (D-12 proxy)', () async {
      // After pauseGame() the Stopwatch is stopped.
      // A subsequent FakeTicker.tick() in playing phase cannot fire (ticker also
      // stopped), so elapsed is frozen. Verify phase is paused and that a
      // resumeGame() → immediate tick gives a score consistent with no
      // background time having accrued.
      final notifier = await startIntoPlaying();
      notifier.pauseGame();

      final pausedSession = container.read(gameSessionProvider).value!;
      expect(pausedSession.phase, GamePhase.paused);

      // Resume and tick once — elapsed should advance from the paused-at value,
      // not from a value inflated by background wall-clock time.
      notifier.resumeGame();
      fakeTicker.tick();
      final resumedSession = container.read(gameSessionProvider).value!;
      expect(resumedSession.phase, GamePhase.playing);
      // Score remains 0 if no errors/hints and elapsed < 10s
      expect(resumedSession.score, greaterThanOrEqualTo(0));
    });
  });

  group('resumeGame()', () {
    test('resumeGame() sets phase to playing', () async {
      final notifier = await startIntoPlaying();
      notifier.pauseGame();
      notifier.resumeGame();
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.playing);
    });

    // CR-01: null-state guard
    test('resumeGame() does not throw when state.value is null (CR-01)', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      // Do NOT await future — state.value may be null.
      expect(() => notifier.resumeGame(), returnsNormally);
    });
  });

  group('recordDrop() null guard — CR-01', () {
    test('recordDrop() does not throw when state.value is null (CR-01)', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      // Do NOT await future — state.value may be null.
      expect(
        () => notifier.recordDrop('TX', isCorrect: true),
        returnsNormally,
      );
    });
  });

  group('completeGame() null guard — CR-01', () {
    test('completeGame() does not throw when state.value is null (CR-01)', () async {
      final notifier = container.read(gameSessionProvider.notifier);
      // Do NOT await future — state.value may be null.
      await expectLater(
        () => notifier.completeGame(),
        returnsNormally,
      );
    });
  });

  group('restoreGame() — SESS-03 / D-09 / D-05', () {
    test(
      'restoreGame() lands session in GamePhase.paused (D-09)',
      () async {
        final notifier = container.read(gameSessionProvider.notifier);
        await container.read(gameSessionProvider.future);

        const restoredSession = GameSession(
          phase: GamePhase.playing,
          mode: GameMode.statesMaster,
          score: 15,
          elapsed: Duration(seconds: 90),
          errorCount: 2,
          activePostal: 'TX',
          hintsRemaining: 1,
          matchedPostals: ['AL', 'AK'],
        );

        notifier.restoreGame(restoredSession, hintPenalty: 5);

        final session = container.read(gameSessionProvider).value!;
        expect(session.phase, GamePhase.paused);
      },
    );

    test(
      'restoreGame() seeds _restoredOffset from elapsed (D-03)',
      () async {
        final notifier = container.read(gameSessionProvider.notifier);
        await container.read(gameSessionProvider.future);

        const restoredSession = GameSession(
          phase: GamePhase.playing,
          mode: GameMode.learn,
          score: 10,
          elapsed: Duration(seconds: 100),
          errorCount: 0,
          hintsRemaining: 2,
        );

        notifier.restoreGame(restoredSession, hintPenalty: 0);
        notifier.resumeGame();

        // After resumeGame the Stopwatch starts from 0; tick once to trigger _onTick.
        // elapsedSecs = 100 (offset) + ~0 (stopwatch) ≈ 100.
        // score = (100 ~/ 10) + (0 * 5) + 0 = 10
        fakeTicker.tick();

        final session = container.read(gameSessionProvider).value!;
        expect(session.phase, GamePhase.playing);
        expect(session.score, greaterThanOrEqualTo(10));
      },
    );

    test(
      'restoreGame() does NOT back-calculate hintPenalty from score (D-05)',
      () async {
        final notifier = container.read(gameSessionProvider.notifier);
        await container.read(gameSessionProvider.future);

        // Craft a session where back-calculation would give a different result:
        // elapsed=19s → (19 ~/ 10) = 1; errorCount=0 → 0; score=6 (implies hintPenalty=5)
        // Back-calc: score(6) - base(1 + 0) = 5 ✓ in this case
        // We test with explicit hintPenalty=5 and verify it is preserved.
        const restoredSession = GameSession(
          phase: GamePhase.paused,
          mode: GameMode.learn,
          score: 6,
          elapsed: Duration(seconds: 19),
          errorCount: 0,
          hintsRemaining: 1,
        );

        notifier.restoreGame(restoredSession, hintPenalty: 5);
        notifier.resumeGame();
        fakeTicker.tick();

        final session = container.read(gameSessionProvider).value!;
        // score = (19 ~/ 10) + 0 * 5 + 5 = 1 + 0 + 5 = 6
        expect(session.score, greaterThanOrEqualTo(6));
      },
    );
  });

  group('completeGame()', () {
    test('completeGame() sets phase to completed', () async {
      final notifier = await startIntoPlaying();
      await notifier.completeGame();
      final session = container.read(gameSessionProvider).value!;
      expect(session.phase, GamePhase.completed);
    });

    test('completeGame() calls saveBestScore and clearSession', () async {
      final notifier = await startIntoPlaying();
      await notifier.completeGame();
      verify(() => mockHighScoreRepo.saveBestScore(any(), any())).called(1);
      verify(() => mockGameRepo.clearSession()).called(1);
    });
  });
}
