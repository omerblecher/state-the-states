---
phase: 02-state-machine-repositories
reviewed: 2026-05-31T00:00:00Z
depth: deep
files_reviewed: 17
files_reviewed_list:
  - lib/core/audio/real_audio_service.dart
  - lib/core/ticker.dart
  - lib/core/data/game_state_repository.dart
  - lib/core/data/high_score_repository.dart
  - lib/core/data/user_prefs_repository.dart
  - lib/features/game/game_phase.dart
  - lib/features/game/game_mode.dart
  - lib/features/game/game_session.dart
  - lib/features/game/game_session_notifier.dart
  - lib/features/game/game_lifecycle_observer.dart
  - test/core/audio/audio_service_test.dart
  - test/core/data/game_state_repository_test.dart
  - test/core/data/high_score_repository_test.dart
  - test/core/data/user_prefs_repository_test.dart
  - test/features/game/game_lifecycle_observer_test.dart
  - test/features/game/game_session_notifier_test.dart
  - test/features/game/game_session_test.dart
findings:
  critical: 3
  warning: 5
  info: 3
  total: 11
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-31T00:00:00Z
**Depth:** deep
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Phase 2 delivers well-structured contracts and correctly applies many of the design decisions (D-02 Stopwatch, D-05 explicit hintPenalty, D-09 restore-to-paused, D-12 stopwatch-first in pause). The Riverpod integration, JSON round-trip, lower-wins scoring, and COPPA compliance are sound. However, three BLOCKER-level bugs were found:

1. `pauseGame()` / `resumeGame()` / `recordDrop()` / `completeGame()` all force-unwrap `state.value!` without null guards, crashing whenever the provider is still loading — `GameLifecycleObserver` triggers this path immediately on app backgrounding.
2. `pauseGame()` unconditionally transitions any phase (including `idle` and `completed`) to `paused` and writes a snapshot — corrupting the repository with a phantom "resumable game" even when no game was ever started.
3. `RealTicker.start()` never cancels the existing `Timer` before creating a new one, so calling `startGame()` (or `resumeGame()`) twice without an intervening `stop()` leaks timers and causes double-firing of `_onTick` (elapsed counted twice per second, countdown ticks at 2×).

---

## Critical Issues

### CR-01: `pauseGame()` and all other state mutators crash when `state.value` is null

**File:** `lib/features/game/game_session_notifier.dart:131`

**Issue:** `pauseGame()` (line 131), `resumeGame()` (line 137), `recordDrop()` (line 156), and `completeGame()` (line 205) all use `state.value!` (force-unwrap) with no null guard. `state.value` is `null` while the `AsyncNotifier.build()` future is still pending — i.e., during the async `SharedPreferences.getInstance()` calls on first launch. The `GameLifecycleObserver` calls `pauseGame()` unconditionally whenever the app is backgrounded, so if the user immediately backgrounds the app at cold start, the force-unwrap throws `Null check operator used on a null value`, crashing the app.

`startGame()` has the correct pattern (`if (current == null) return;`) that the other methods lack.

**Fix:** Add an early-return null guard to every public mutator that reads `state.value`:

```dart
void pauseGame() {
  final current = state.value;
  if (current == null) return;           // provider still loading — ignore
  _stopwatch.stop();
  _ticker.stop();
  state = AsyncData(current.copyWith(phase: GamePhase.paused));
  _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
}

void resumeGame() {
  final current = state.value;
  if (current == null) return;
  state = AsyncData(current.copyWith(phase: GamePhase.playing));
  _stopwatch.start();
  _ticker.start(_onTick);
}

void recordDrop(String postal, {required bool isCorrect}) {
  final current = state.value;
  if (current == null) return;
  // ... rest of method
}

Future<void> completeGame() async {
  final current = state.value;
  if (current == null) return;
  // ... rest of method
}
```

---

### CR-02: `pauseGame()` corrupts repository when called in non-playing phases

**File:** `lib/features/game/game_session_notifier.dart:126`

**Issue:** `pauseGame()` has no phase guard — it transitions any phase unconditionally to `paused` and writes a snapshot. The `GameLifecycleObserver` calls it on every backgrounding event. Concrete harm:

- **App backgrounded in `idle` phase** (e.g., user opens app then immediately switches away): `phase` is forced to `paused`, and `saveSession` writes a snapshot with `phase=paused`, `score=0`, `elapsed=0`. On next launch, `loadSession()` returns this phantom snapshot. Phase 4 code that checks for a resumable game will offer to resume a game that was never started.
- **App backgrounded in `completed` phase** (user sees win screen, switches away): `completeGame()` already called `clearSession()`, but `pauseGame()` now writes a new snapshot with `phase=paused` and the completed score. The cleared state is re-polluted.
- **App backgrounded in `paused` phase**: double-pause writes an unnecessary snapshot, leaking the `Future` from the unawaited `saveSession` call.

**Fix:** Add a phase guard so `pauseGame()` is a no-op outside `playing` (and `countdown` if desired):

```dart
void pauseGame() {
  final current = state.value;
  if (current == null) return;
  // Only auto-pause when a game is actively running.
  if (current.phase != GamePhase.playing &&
      current.phase != GamePhase.countdown) {
    return;
  }
  _stopwatch.stop();
  _ticker.stop();
  state = AsyncData(current.copyWith(phase: GamePhase.paused));
  _gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
}
```

---

### CR-03: `RealTicker.start()` leaks `Timer` when called without a prior `stop()`

**File:** `lib/core/ticker.dart:14`

**Issue:** `RealTicker.start()` unconditionally assigns `_timer = Timer.periodic(...)` without first cancelling any existing timer. If `start()` is called twice (e.g., `startGame()` called on an active game, or `resumeGame()` called on an already-playing session), the old `Timer` is orphaned — it fires indefinitely, it cannot be cancelled (its reference is lost), and `_onTick` fires twice per second. In the countdown this doubles `_countdownTick` so the countdown ends in ~2.5 real seconds instead of 5. In `playing` phase it doubles the elapsed-time signal, running the score up at 2× speed.

The notifier does not prevent `startGame()` from being called on an active game (e.g., if the UI back-button restarts the game). Two games running simultaneously is a realistic failure path.

**Fix:** Cancel any live timer at the start of `start()`:

```dart
@override
void start(void Function() onTick) {
  _timer?.cancel();       // cancel before overwriting
  _onTick = onTick;
  _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick!());
}
```

---

## Warnings

### WR-01: `RealAudioService.dispose()` crashes with `LateInitializationError` if `init()` was never called

**File:** `lib/core/audio/real_audio_service.dart:93`

**Issue:** `_correctPlayer`, `_errorPlayer`, and `_anthemPlayer` are `late` fields assigned inside `init()`. The comment in `dispose()` correctly explains that they are assigned *before* the try block within `init()`, so a partial `init()` failure is safe. However, the comment does NOT cover the case where `init()` was **never called at all** (e.g., if the app's DI wiring skips the init call). Calling `dispose()` before `init()` throws `LateInitializationError: Field '_correctPlayer@...' has not been initialized.` — an unhandled exception in the dispose path that can cause resource leaks.

**Fix:** Either initialise the players at declaration time (eagerly), or add a guard in `dispose()`:

```dart
// Option A (preferred): eager initialization — no late needed
AudioPlayer _correctPlayer = AudioPlayer();
AudioPlayer _errorPlayer   = AudioPlayer();
AudioPlayer _anthemPlayer  = AudioPlayer();
```

OR:

```dart
// Option B: guard in dispose()
@override
Future<void> dispose() async {
  if (!_initialized && /* _correctPlayer not yet assigned */ true) return;
  await _correctPlayer.dispose();
  await _errorPlayer.dispose();
  await _anthemPlayer.dispose();
}
```

Option A is cleaner; `AudioPlayer()` construction is cheap and side-effect-free.

---

### WR-02: `_stopwatch` not reset in `build()` — running stopwatch survives provider rebuild

**File:** `lib/features/game/game_session_notifier.dart:52`

**Issue:** `build()` resets `_countdownTick`, `_hintPenalty`, and `_restoredOffset`, but does NOT reset or stop `_stopwatch`. `_stopwatch` is a `final` field initialized once. If the provider rebuilds (a `ref.watch()` dependency invalidates, or Riverpod disposes and re-creates the notifier), any previously running stopwatch keeps ticking. On the subsequent `startGame()` call, `_stopwatch.reset()` is called — so the common path is safe. But a `_onTick()` firing in the window between a rebuild and `startGame()` would read a non-zero `_stopwatch.elapsed` combined with `_restoredOffset = 0`, producing a non-zero elapsed/score in what should be an idle state.

**Fix:** Add `_stopwatch.stop(); _stopwatch.reset();` to `build()`:

```dart
Future<GameSession> build() async {
  _stopwatch.stop();    // add these two lines
  _stopwatch.reset();
  _countdownTick = 0;
  _hintPenalty = 0;
  _restoredOffset = 0;
  ref.onDispose(_ticker.stop);
  // ...
}
```

---

### WR-03: `pauseGame()` snapshot write is unawaited — no write-completion guarantee for process-death survival

**File:** `lib/features/game/game_session_notifier.dart:133`

**Issue:** The purpose of flushing the snapshot in `pauseGame()` is crash / process-death survival (D-07). However:

```dart
_gameStateRepository?.saveSession(state.value!, hintPenalty: _hintPenalty);
// unawaited Future<void>
```

`pauseGame()` is a synchronous method (`void`) so it cannot `await`. The enqueued `SharedPreferences.setString` write is dispatched to the platform channel but may not have committed by the time the OS reclaims the process (e.g. a fast SIGKILL after `AppLifecycleState.paused`). The incorrect-drop path has the same behavior by design (documented D-07 tradeoff). However `pauseGame()` is specifically the crash-survival flush and deserves a stronger contract.

**Fix:** Change `pauseGame()` to `Future<void>` and await the snapshot write:

```dart
Future<void> pauseGame() async {
  final current = state.value;
  if (current == null) return;
  if (current.phase != GamePhase.playing &&
      current.phase != GamePhase.countdown) {
    return;
  }
  _stopwatch.stop();
  _ticker.stop();
  final paused = current.copyWith(phase: GamePhase.paused);
  state = AsyncData(paused);
  await _gameStateRepository?.saveSession(paused, hintPenalty: _hintPenalty);
}
```

Note: `GameLifecycleObserver.didChangeAppLifecycleState` is synchronous and cannot await, but the platform guarantees a brief grace period after `AppLifecycleState.paused` before fully suspending — `SharedPreferences.setString` is fast enough that `unawaited(notifier.pauseGame())` in the observer still gives a meaningful improvement over the current synchronous dispatch.

---

### WR-04: `completeGame()` saves stale pre-tick score to high-score repository

**File:** `lib/features/game/game_session_notifier.dart:202`

**Issue:** `completeGame()` captures `current = state.value!` and then calls `saveBestScore(current.mode, current.score)`. The score in `current` is the value from the last `_onTick()` call (which fires once per second). Between the last tick and `completeGame()` being called, up to ~1 second of stopwatch time has elapsed — but `_onTick` hasn't fired to recalculate the score. The final high-score entry therefore under-represents the true elapsed time by up to 1 second.

In a lower-wins system this benefits the player (lower recorded score), but the score shown on the completion screen could differ from the score persisted if the UI re-reads the session after the phase transition. The newly set `state` (phase=completed) carries `current.score` — the same stale value — so both display and persist agree, but the final score is not the true final score.

**Fix:** Recalculate the score at the moment of completion before locking it in:

```dart
Future<void> completeGame() async {
  _stopwatch.stop();
  _ticker.stop();
  final current = state.value!;
  // Compute final score now that the stopwatch is stopped.
  final finalElapsed = _restoredOffset + _stopwatch.elapsed.inSeconds;
  final finalScore =
      (finalElapsed ~/ 10) + (current.errorCount * 5) + _hintPenalty;
  final completed = current.copyWith(
    phase: GamePhase.completed,
    score: finalScore,
    elapsed: Duration(seconds: finalElapsed),
  );
  state = AsyncData(completed);
  if (_highScoreRepository != null) {
    await _highScoreRepository!.saveBestScore(completed.mode, completed.score);
  }
  await _gameStateRepository?.clearSession();
}
```

---

### WR-05: `ref.onDispose(_ticker.stop)` registered on every `build()` call accumulates redundant dispose callbacks

**File:** `lib/features/game/game_session_notifier.dart:56`

**Issue:** `build()` unconditionally registers `ref.onDispose(_ticker.stop)` on every invocation. In Riverpod 3.x, `ref.onDispose` callbacks are re-registered on each rebuild cycle without deduplication. If the provider rebuilds N times (e.g., a watched dependency changes), there will be N `_ticker.stop` callbacks registered, all firing on the final dispose. While `stop()` is idempotent, N redundant calls add noise and may interact unexpectedly with future changes to `stop()`.

**Fix:** Guard with a flag, or restructure so `_ticker.stop` is only registered once:

```dart
bool _disposeRegistered = false;

Future<GameSession> build() async {
  if (!_disposeRegistered) {
    ref.onDispose(_ticker.stop);
    _disposeRegistered = true;
  }
  // ...
}
```

---

## Info

### IN-01: Magic number `2` for `hintsRemaining` is hardcoded without per-mode configuration

**File:** `lib/features/game/game_session_notifier.dart:72,95`

**Issue:** `hintsRemaining: 2` is hardcoded in both `build()` and `startGame()`. There is no per-mode hint allotment. Higher difficulty modes (e.g., `grandMaster`) may warrant 0 hints. Hardcoding this now makes it a Phase 4 breaking change to introduce mode-specific hint budgets, since it touches `startGame()`.

**Fix:** Extract to a named constant or a mode-dispatch helper so Phase 4 can patch one site:

```dart
static int _hintsForMode(GameMode mode) => switch (mode) {
  GameMode.grandMaster => 0,
  _                    => 2,
};
```

---

### IN-02: `_remainingPostals` field is declared but annotated `// ignore: unused_field`

**File:** `lib/features/game/game_session_notifier.dart:48`

**Issue:** `_remainingPostals` is declared as a `List<String>` field with a lint-suppression comment, intended for Phase 4. This is carrying dead code across a phase boundary. The suppress comment will age poorly — future `flutter analyze` runs will still require the annotation, and it may mislead reviewers about whether Phase 4 landed.

**Fix:** Either remove the field entirely and add it in Phase 4 when it's needed, or at minimum document the Phase 4 task reference:

```dart
// Phase 4: populated by mode-specific logic (see Phase 4 plan, SCORE-03).
List<String> _remainingPostals = [];
```

---

### IN-03: Test `game_lifecycle_observer_test.dart` does not test that `pauseGame()` is NOT called when state is `idle` (phase-guard gap)

**File:** `test/features/game/game_lifecycle_observer_test.dart`

**Issue:** The lifecycle observer tests verify D-11 (`.inactive` and `.resumed` don't trigger pause) and that `.paused`/`.hidden` do trigger pause. But they do not verify the intended behavior when `pauseGame()` is called from idle/completed phase — specifically, once CR-02's phase guard is added, there should be a test that the lifecycle observer fires `pauseGame()` but the notifier ignores it when in idle phase. Without this test, the fix for CR-02 has no regression coverage.

**Fix:** After fixing CR-02, add a test:

```dart
test(
  'backgrounding when game is idle does not write a snapshot (CR-02 guard)',
  () async {
    // notifier in idle phase
    final notifier = container.read(gameSessionProvider.notifier);
    await container.read(gameSessionProvider.future);
    // phase is idle — simulate background
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    final session = container.read(gameSessionProvider).value!;
    expect(session.phase, GamePhase.idle);  // must NOT become paused
    verifyNever(() => mockGameRepo.saveSession(any(), hintPenalty: any(named: 'hintPenalty')));
  },
);
```

---

_Reviewed: 2026-05-31_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
