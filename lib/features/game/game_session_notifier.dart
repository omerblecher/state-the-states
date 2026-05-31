// Source: C:\code\Claude\FlagsRoundTheWorld\lib\features\game\game_session_notifier.dart
// Deltas applied:
//   D-02: Stopwatch replaces _elapsedSeconds counter (Stopwatch is elapsed source)
//   D-05: restoreGame() accepts explicit hintPenalty (no back-calculation from score)
//   D-09: restoreGame() lands in GamePhase.paused, not playing
//   D-12: pauseGame() calls _stopwatch.stop() AS FIRST ACTION (prevents background accrual)
// Field renames: activeIsoCode → activePostal, matchedIsoCodes → matchedPostals,
//   _remainingIsoCodes → _remainingPostals
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_states/core/data/game_state_repository.dart';
import 'package:state_states/core/data/high_score_repository.dart';
import 'package:state_states/core/ticker.dart';
import 'package:state_states/features/game/game_mode.dart';
import 'package:state_states/features/game/game_phase.dart';
import 'package:state_states/features/game/game_session.dart';

final gameSessionProvider =
    AsyncNotifierProvider<GameSessionNotifier, GameSession>(
  () => GameSessionNotifier(ticker: RealTicker()),
);

class GameSessionNotifier extends AsyncNotifier<GameSession> {
  GameSessionNotifier({
    required Ticker ticker,
    GameStateRepository? gameStateRepository,
    HighScoreRepository? highScoreRepository,
  })  : _ticker = ticker,
        _gameStateRepository = gameStateRepository,
        _highScoreRepository = highScoreRepository;

  final Ticker _ticker;
  GameStateRepository? _gameStateRepository;
  HighScoreRepository? _highScoreRepository;

  // D-02: Stopwatch is the single source of truth for elapsed time.
  // NEVER add _elapsedSeconds — the Stopwatch replaces that Flags model.
  final Stopwatch _stopwatch = Stopwatch();

  /// Seeded by restoreGame() from the persisted elapsedSeconds (D-03).
  /// Zero on a fresh startGame().
  int _restoredOffset = 0;

  int _countdownTick = 0;
  int _hintPenalty = 0;

  // Populated by Phase 4 mode-specific logic; kept here so the notifier
  // owns the full session state without model changes in a later phase.
  // ignore: unused_field
  List<String> _remainingPostals = [];

  @override
  Future<GameSession> build() async {
    _countdownTick = 0;
    _hintPenalty = 0;
    _restoredOffset = 0;
    ref.onDispose(_ticker.stop);

    // Wire repositories from providers if not injected by tests.
    _gameStateRepository ??=
        await ref.watch(gameStateRepositoryProvider.future);
    _highScoreRepository ??=
        await ref.watch(highScoreRepositoryProvider.future);

    return const GameSession(
      phase: GamePhase.idle,
      mode: GameMode.learn,
      score: 0,
      elapsed: Duration.zero,
      errorCount: 0,
      activePostal: null,
      hintsRemaining: 2,
    );
  }

  /// Number of countdown seconds remaining (5 → 4 → … → 1 → 0).
  int get countdownSecondsRemaining => 5 - _countdownTick;

  void startGame(GameMode mode) {
    final current = state.value;
    if (current == null) return; // Provider still loading.
    // D-02: reset Stopwatch; it does NOT start until countdown → playing.
    _stopwatch.reset();
    _restoredOffset = 0;
    _countdownTick = 0;
    _hintPenalty = 0;
    _remainingPostals = [];
    state = AsyncData(
      current.copyWith(
        phase: GamePhase.countdown,
        mode: mode,
        score: 0,
        elapsed: Duration.zero,
        errorCount: 0,
        activePostal: null,
        hintsRemaining: 2,
      ),
    );
    _ticker.start(_onTick);
  }

  // D-02: The ticker is a display-only pulse. It triggers a re-read of
  // _stopwatch.elapsed; it never increments a counter.
  void _onTick() {
    final current = state.value;
    if (current == null) return;

    if (current.phase == GamePhase.countdown) {
      _countdownTick++;
      if (_countdownTick >= 5) {
        // D-01: Stopwatch starts ONLY when leaving countdown → playing.
        _stopwatch.start();
        state = AsyncData(current.copyWith(phase: GamePhase.playing));
      }
    } else if (current.phase == GamePhase.playing) {
      // D-02: read Stopwatch + offset; never increment a counter.
      final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
      final score =
          (elapsedSecs ~/ 10) + (current.errorCount * 5) + _hintPenalty;
      state = AsyncData(current.copyWith(
        score: score,
        elapsed: Duration(seconds: elapsedSecs),
      ));
    }
  }

  void pauseGame() {
    final current = state.value;
    if (current == null) return; // provider still loading — ignore (CR-01)
    // CR-02: only auto-pause when a game is actively running; backgrounding in
    // idle or completed must not write a phantom snapshot to the repository.
    if (current.phase != GamePhase.playing &&
        current.phase != GamePhase.countdown) {
      return;
    }
    // D-02/D-12: _stopwatch.stop() is the ONLY thing that prevents background
    // time from accumulating. Must come before the state update.
    _stopwatch.stop();
    _ticker.stop();
    final paused = current.copyWith(phase: GamePhase.paused);
    state = AsyncData(paused);
    // D-07: flush snapshot on pause.
    _gameStateRepository?.saveSession(paused, hintPenalty: _hintPenalty);
  }

  void resumeGame() {
    final current = state.value;
    if (current == null) return; // provider still loading — ignore (CR-01)
    state = AsyncData(current.copyWith(phase: GamePhase.playing));
    _stopwatch.start(); // Resume Stopwatch from where it stopped.
    _ticker.start(_onTick);
  }

  // D-05: hintPenalty is passed explicitly from loadSession() — NOT back-calculated.
  // D-09: restore to paused; player taps Resume to start the clock.
  void restoreGame(GameSession restoredSession, {required int hintPenalty}) {
    _ticker.stop();
    _stopwatch.reset(); // Stopwatch starts from zero; offset carries the history.
    _restoredOffset = restoredSession.elapsed.inSeconds;
    _hintPenalty = hintPenalty; // D-05: explicit, not back-calculated.
    _countdownTick = 0;
    // D-09: restore to paused — player taps Resume to start the clock.
    state = AsyncData(restoredSession.copyWith(phase: GamePhase.paused));
    // Stopwatch is NOT started here — stays stopped until resumeGame().
  }

  void recordDrop(String postal, {required bool isCorrect}) {
    final current = state.value;
    if (current == null) return; // provider still loading — ignore (CR-01)
    if (isCorrect) {
      final updated = current.copyWith(
        matchedPostals: [...current.matchedPostals, postal],
      );
      state = AsyncData(updated);
      // D-07: flush on correct drop.
      // NOTE: saveSession is unawaited by convention (void method); a kill-9
      // right after this call can lose the write. SharedPreferences enqueues
      // the write to the platform — this is the documented D-07 tradeoff.
      _gameStateRepository?.saveSession(updated, hintPenalty: _hintPenalty);
    } else {
      final newErrorCount = current.errorCount + 1;
      final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
      final newScore =
          (elapsedSecs ~/ 10) + (newErrorCount * 5) + _hintPenalty;
      state = AsyncData(current.copyWith(
        errorCount: newErrorCount,
        score: newScore,
      ));
    }
  }

  /// Consumes one hint from hintsRemaining.
  ///
  /// Returns true if a hint was consumed; returns false if hintsRemaining is
  /// already 0 or the game is not in the playing phase.
  bool useHint() {
    final current = state.value;
    if (current == null ||
        current.phase != GamePhase.playing ||
        current.hintsRemaining <= 0) {
      return false;
    }
    _hintPenalty += 5;
    final elapsedSecs = _restoredOffset + _stopwatch.elapsed.inSeconds;
    final newScore =
        (elapsedSecs ~/ 10) + (current.errorCount * 5) + _hintPenalty;
    state = AsyncData(current.copyWith(
      hintsRemaining: current.hintsRemaining - 1,
      score: newScore,
    ));
    _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
    return true;
  }

  Future<void> completeGame() async {
    _stopwatch.stop(); // Stopwatch has no more work to do.
    _ticker.stop();
    final current = state.value;
    if (current == null) return; // provider still loading — ignore (CR-01)
    state = AsyncData(current.copyWith(phase: GamePhase.completed));
    if (_highScoreRepository != null) {
      await _highScoreRepository!.saveBestScore(current.mode, current.score);
    }
    // Clear saved session so the home screen never offers to "continue"
    // a finished game.
    await _gameStateRepository?.clearSession();
  }
}
