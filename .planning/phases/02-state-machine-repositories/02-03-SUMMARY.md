---
phase: 02-state-machine-repositories
plan: "03"
subsystem: game-logic
tags: [state-machine, riverpod, async-notifier, lifecycle, tdd]
dependency_graph:
  requires: ["02-01", "02-02"]
  provides:
    - gameSessionProvider (AsyncNotifierProvider<GameSessionNotifier, GameSession>)
    - GameLifecycleObserver (WidgetsBindingObserver auto-pause glue)
  affects:
    - "Phase 4 game screen (mounts GameLifecycleObserver)"
    - "Phase 4 game screen (reads gameSessionProvider state)"
tech_stack:
  added: []
  patterns:
    - "Stopwatch-as-truth timer (D-02): ticker is display-only pulse, Stopwatch is elapsed source"
    - "pauseGame() calls _stopwatch.stop() as first action (D-12): prevents background accrual"
    - "restoreGame() lands in GamePhase.paused with explicit hintPenalty (D-05/D-09)"
    - "GameLifecycleObserver pauses on .paused/.hidden only, ignores .inactive (D-11)"
    - "ProviderContainer + FakeTicker override pattern for deterministic notifier tests"
    - "mocktail registerFallbackValue for GameSession and GameMode"
key_files:
  created:
    - lib/features/game/game_session_notifier.dart
    - lib/features/game/game_lifecycle_observer.dart
    - test/features/game/game_session_notifier_test.dart
    - test/features/game/game_lifecycle_observer_test.dart
  modified:
    - test/core/audio/audio_service_test.dart (remove unused dart:async import)
decisions:
  - "Stopwatch replaces _elapsedSeconds counter (D-02): dropping/duplicating ticks cannot corrupt elapsed"
  - "pauseGame() calls _stopwatch.stop() as first action (D-12): this is the only thing that delivers 30s-background = +0s"
  - "restoreGame() accepts explicit hintPenalty parameter (D-05): no back-calculation from score"
  - "restoreGame() lands in GamePhase.paused (D-09): player taps Resume to start the clock"
  - "GameLifecycleObserver ignores .inactive (D-11): avoids false pauses on iOS transient overlays"
  - "Stopwatch not injected as constructor parameter: isRunning-based tests are sufficient for Phase 2; injection deferred if CI flakiness emerges"
metrics:
  duration: "~35 minutes"
  completed: "2026-05-31"
  tasks_completed: 2
  files_created: 4
  files_modified: 1
---

# Phase 02 Plan 03: GameSessionNotifier + GameLifecycleObserver Summary

**One-liner:** Stopwatch-as-truth AsyncNotifier state machine with explicit hintPenalty restore-to-paused, plus WidgetsBindingObserver auto-pause glue filtered to .paused/.hidden only.

## What Was Built

### Task 1: GameSessionNotifier (TDD)

`lib/features/game/game_session_notifier.dart` — Port of the Flags `GameSessionNotifier` with three load-bearing behavioral deltas:

**D-02 (Stopwatch model):** `_elapsedSeconds` counter removed entirely. `final Stopwatch _stopwatch = Stopwatch()` is the elapsed source. `_onTick()` reads `_restoredOffset + _stopwatch.elapsed.inSeconds` — never increments a counter. A dropped/duplicated tick cannot corrupt elapsed.

**D-12 (load-bearing pause):** `pauseGame()` calls `_stopwatch.stop()` as its FIRST action before `_ticker.stop()` and before the state update. This is the only mechanism that delivers "30s backgrounded = +0s".

**D-05/D-09 (restore):** `restoreGame(session, {required int hintPenalty})` accepts hintPenalty explicitly (no back-calculation from score), seeds `_restoredOffset`, and sets `GamePhase.paused`. Stopwatch is NOT started.

Provider: `gameSessionProvider = AsyncNotifierProvider<GameSessionNotifier, GameSession>(() => GameSessionNotifier(ticker: RealTicker()))`.

Constructor accepts optional `GameStateRepository?` and `HighScoreRepository?` for test injection.

**Test coverage (20 tests):** Scoring formula with fixed inputs (SCORE-01/02), recordDrop/useHint behavior, pauseGame sets paused and flushes saveSession (D-07), elapsed-does-not-advance-after-pause proxy (D-12), restoreGame lands in paused (D-09), restoreGame seeds offset from elapsed (D-03), completeGame calls saveBestScore + clearSession.

### Task 2: GameLifecycleObserver (TDD)

`lib/features/game/game_lifecycle_observer.dart` — New file with no Flags equivalent. Implements D-10/D-11.

`GameLifecycleObserver extends WidgetsBindingObserver`, constructor `GameLifecycleObserver(this._notifier)`. `didChangeAppLifecycleState` calls `_notifier.pauseGame()` ONLY for `.paused` and `.hidden`. `.inactive` is explicitly ignored (iOS transient overlays cause false pauses). `.resumed` is explicitly ignored (player taps Resume manually per D-09).

Registration via `WidgetsBinding.instance.addObserver(this)` / `removeObserver(this)` is deferred to Phase 4 game screen.

**Test coverage (4 widget tests):** `.paused` → `verify(...).called(1)`, `.hidden` → `verify(...).called(1)`, `.inactive` → `verifyNever(...)`, `.resumed` → `verifyNever(...)`.

## Acceptance Criteria Verification

| Criterion | Status | Evidence |
|-----------|--------|----------|
| `final Stopwatch _stopwatch` exists | PASS | Line 40 of game_session_notifier.dart |
| No `_elapsedSeconds` field | PASS | `grep "int _elapsedSeconds"` returns nothing |
| `pauseGame()` calls `_stopwatch.stop()` before state update | PASS | Lines 116-120 of notifier |
| `restoreGame` has `{required int hintPenalty}` parameter | PASS | Line 150 of notifier |
| `restoreGame` sets `GamePhase.paused` | PASS | Line 158 of notifier |
| No `score - baseScore` back-calculation in `restoreGame` | PASS | Method body contains no subtraction from score |
| `_onTick` reads `_stopwatch.elapsed`, no `++` on elapsed counter | PASS | Lines 130-140 of notifier |
| No ads imports (COMP-03 walled garden) | PASS | `grep -niE "import .*ads"` returns nothing |
| `flutter test test/features/game/game_session_notifier_test.dart` exits 0 | PASS | 20/20 tests green |
| `flutter test test/features/game/game_lifecycle_observer_test.dart` exits 0 | PASS | 4/4 tests green |
| `flutter test` full suite exits 0 | PASS | 59/59 tests green |
| `flutter analyze` clean | PASS | "No issues found!" |
| Observer has `extends WidgetsBindingObserver` | PASS | Line 27 of observer |
| Handler references `.paused` and `.hidden` | PASS | Lines 38-39 of observer |
| Handler does NOT reference `.inactive` in pause branch | PASS | Only in comment (D-11 rationale) |
| `verifyNever` for `.inactive` test | PASS | Line 54 of observer test |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] mocktail registerFallbackValue required for GameSession**
- **Found during:** Task 1, GREEN phase (first test run)
- **Issue:** mocktail `any()` matcher on a non-nullable `GameSession` parameter in `saveSession(any(), hintPenalty: any(named: 'hintPenalty'))` throws `Bad state: registerFallbackValue not called`
- **Fix:** Added `setUpAll { registerFallbackValue(const GameSession(...)); registerFallbackValue(GameMode.learn); }` to the test
- **Files modified:** `test/features/game/game_session_notifier_test.dart`
- **Commit:** 71d39d0 (included in task 1 commit)

**2. [Rule 1 - Bug] Lint: leading underscore on local function**
- **Found during:** Task 2 verification (`flutter analyze`)
- **Issue:** `no_leading_underscores_for_local_identifiers` lint on `_startIntoPlaying` helper function in notifier test
- **Fix:** Renamed to `startIntoPlaying`, replaced all call sites
- **Files modified:** `test/features/game/game_session_notifier_test.dart`
- **Commit:** 81819a9 (included in task 2 commit)

**3. [Rule 1 - Bug] Unused import in prior-wave test file**
- **Found during:** Task 2 verification (`flutter analyze`)
- **Issue:** `import 'dart:async';` in `test/core/audio/audio_service_test.dart` was unused
- **Fix:** Removed the import
- **Files modified:** `test/core/audio/audio_service_test.dart`
- **Commit:** 81819a9 (included in task 2 commit)

## Known Stubs

None. Both source files are fully implemented. The observer's `WidgetsBinding.instance.addObserver` registration is intentionally deferred to Phase 4 (per D-10) — this is documented in the file's doc comment, not a stub.

## Self-Check: PASSED

All created files found on disk. Both task commits (71d39d0, 81819a9) verified in git log. Full test suite: 59/59 green. Analyze: clean.

## Threat Flags

No new threat surface introduced. Verified:
- `GameSessionNotifier` imports: `flutter_riverpod`, game types, ticker, two repositories — no ads-module imports (COMP-03).
- `GameLifecycleObserver` imports: `flutter/widgets.dart`, `game_session_notifier.dart` — no ads-module imports.
- No new network endpoints, no new persisted fields beyond the hintPenalty already audited in Plan 02 (T-02-07 scope).
