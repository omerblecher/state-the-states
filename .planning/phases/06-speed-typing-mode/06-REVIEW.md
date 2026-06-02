---
phase: 06-speed-typing-mode
reviewed: 2026-06-02T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/app.dart
  - lib/core/data/high_score_repository.dart
  - lib/features/game/game_mode.dart
  - lib/features/game/game_session_notifier.dart
  - lib/features/home/home_screen.dart
  - lib/features/home/session_restore_card.dart
  - lib/features/map/completion_screen.dart
  - lib/features/map/map_screen.dart
  - lib/features/typing/speed_typing_screen.dart
  - test/features/game/game_session_notifier_test.dart
  - test/features/home/home_screen_test.dart
  - test/features/typing/speed_typing_screen_test.dart
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-06-02T00:00:00Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 6 adds Speed Typing Mode: a new `GameMode.speedTyping` enum value, a `SpeedTypingScreen` widget, `submitTyping()` on `GameSessionNotifier`, and plumbing through the home screen and completion flow. The code is well-structured and applies known patterns from MapScreen correctly in several places. However, three critical bugs were found: the game-completion condition in `submitTyping()` can never fire in production, the completion screen shows wrong star counts for Speed Typing games (first-game always shows 2 stars instead of 3), and `completeGame()` is called twice causing a race on high-score persistence. Four warnings address code quality and correctness concerns.

---

## Critical Issues

### CR-01: `submitTyping` game-end condition fires against wrong count — game never ends

**File:** `lib/features/game/game_session_notifier.dart:252`

**Issue:** The game-end check compares `updated.matchedPostals.length == states.length`, where `states` is the full `mapData.states` list passed from `SpeedTypingScreen`. That list contains 51 records (50 placeable states + DC). DC has `isPlaceable: false` and is skipped by the match loop (line 210: `if (!s.isPlaceable) continue;`), so only 50 postals can ever enter `matchedPostals`. The condition `50 == 51` is permanently false — `completeGame()` is never triggered. Speed Typing Mode games cannot be completed.

MapScreen avoids this by filtering DC before building `_remainingPostals`:
```dart
// map_screen.dart:278
final playable = states.where((s) => s.postal != 'DC').map(...).toList();
```
`submitTyping` has no equivalent filter.

**Fix:**
```dart
// game_session_notifier.dart — replace line 252
final placeableCount = states.where((s) => s.isPlaceable).length;
if (updated.matchedPostals.length == placeableCount) {
  completeGame();
}
```
Alternatively, pass only placeable states from the call site:
```dart
// speed_typing_screen.dart — in _onSubmit, replace:
final hit = ref.read(gameSessionProvider.notifier)
    .submitTyping(trimmed, mapData.states.where((s) => s.isPlaceable).toList());
```

---

### CR-02: `completeGame()` double-call corrupts `previousBest` — first Speed Typing game always shows 2 stars instead of 3

**File:** `lib/features/typing/speed_typing_screen.dart:279–293`

**Issue:** `submitTyping()` calls `completeGame()` fire-and-forget when all states are matched. `completeGame()` immediately calls `saveBestScore(mode, score)`, persisting the score to SharedPreferences. On the next build, `SpeedTypingScreen` detects `phase == GamePhase.completed` and schedules another post-frame callback that:
1. Reads `previousBest = await repo.getBestScore(...)` — **this now returns the score just saved by the first `completeGame()` call**
2. Calls `completeGame()` again (redundant but benign)
3. Navigates to `/complete` with `previousBest = currentScore`

At `CompletionScreen.initState`, `score == previousBest` which means `score <= (prev * 1.20).ceil()` → **2 stars**. A player who just set their personal best on their first Speed Typing game will see 2 stars, not 3.

MapScreen avoids this by fetching `previousBest` BEFORE calling `completeGame()` (`_advanceToNextPostal`, line 361–363). SpeedTypingScreen inverts that order because it relies on `submitTyping()` having already called `completeGame()`.

**Fix:** Remove the `completeGame()` call from `submitTyping()` and move game-completion responsibility entirely to `SpeedTypingScreen`, mirroring the MapScreen pattern:

```dart
// game_session_notifier.dart — submitTyping() — replace completeGame() fire-and-forget:
final placeableCount = states.where((s) => s.isPlaceable).length;
if (updated.matchedPostals.length == placeableCount) {
  // Signal completion via state only; caller is responsible for navigating.
  state = AsyncData(updated.copyWith(phase: GamePhase.completed));
}

// speed_typing_screen.dart — in the completed-phase guard:
if (session.phase == GamePhase.completed && !_navigationPending) {
  _navigationPending = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    final repo = await ref.read(highScoreRepositoryProvider.future);
    final prev = await repo.getBestScore(GameMode.speedTyping); // BEFORE saveBestScore
    await ref.read(gameSessionProvider.notifier).completeGame();  // saves score here
    if (!mounted) return;
    context.go('/complete', extra: {'session': session, 'previousBest': prev});
  });
}
```

Note: this fix also resolves CR-01 if the placeableCount change is applied here.

---

### CR-03: `share_plus` is shipped active in v1 despite being deferred to v2

**File:** `lib/features/map/completion_screen.dart:6–7, 98–101`

**Issue:** CLAUDE.md explicitly states: "share_plus — Deferred to v2 (gated social sharing behind math parental challenge)." The completion screen actively imports `share_plus` and calls `SharePlus.instance.share(ShareParams(...))` at line 98. This is live v1 code.

While the math-challenge gate (`_MathChallengeDialog`) partially addresses the COPPA requirement of adult verification, the CLAUDE.md architecture decision deferred this feature to v2. Shipping it in v1 risks:
- Play Store review complications if the share sheet functionality doesn't meet Families Policy review in the initial submission
- Inconsistency with the stated architecture plan

**Fix:** Guard the share button with a compile-time or runtime flag (matching the v1/v2 delineation), or remove the Share button until v2:
```dart
// completion_screen.dart — either remove the share OutlinedButton entirely,
// or wrap it:
if (kDebugMode) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    height: 48,
    child: OutlinedButton.icon(
      onPressed: _onSharePressed,
      icon: const Icon(Icons.share),
      label: const Text('Share result'),
    ),
  ),
],
```

---

## Warnings

### WR-01: `_starsForScore` on HomeScreen always returns 3 stars — rating is meaningless

**File:** `lib/features/home/home_screen.dart:238–243`

**Issue:** `_starsForScore(int? score)` calls `computeStarCount(score, null)`. The first branch of `computeStarCount` is `if (previousBest == null) return 3`. Passing `null` unconditionally means any mode with any stored score always shows 3 stars. The comment ("A stored best score is by definition a personal best") is logically sound but the implementation provides no useful signal to the user. Players who scored poorly always see 3 stars on the home screen, which undermines the rating system.

**Fix:** Store mode scores per game and display stars relative to a threshold, or simply omit stars when there is only one recorded game:
```dart
int _starsForScore(int? score) {
  if (score == null) return 0;
  // Without a second score to compare to, show 1 star as a baseline indicator
  // (not 3, which implies excellence).
  return 1;
}
```
Or, persist the second-to-last score to enable a meaningful comparison.

---

### WR-02: `FutureBuilder` in `HomeScreen._buildBody` recreates the future on every rebuild

**File:** `lib/features/home/home_screen.dart:41–68`

**Issue:** The `FutureBuilder` at line 41 computes its `future` inline:
```dart
future: ref
    .read(gameStateRepositoryProvider.future)
    .then((r) => r.loadSession()),
```
`ref.read` is called on every invocation of `_buildBody`, which runs on every rebuild (including rebuilds triggered by `setState`). Each call creates a new `Future` chain. `FutureBuilder` tracks the `future` reference — when it changes, the builder briefly returns to the `ConnectionState.waiting` state, causing the restore card to momentarily disappear and reappear after the `onDismiss` → `setState()` flow.

**Fix:** Cache the future in state (set once in `initState`), or use `ref.watch` with a proper `AsyncValue`:
```dart
// In _HomeScreenState:
late Future<({GameSession session, int hintPenalty})?> _restoreSessionFuture;

@override
void initState() {
  super.initState();
  _restoreSessionFuture = ref
      .read(gameStateRepositoryProvider.future)
      .then((r) => r.loadSession());
}

// In onDismiss, instead of setState:
onDismiss: () {
  ref.read(gameSessionProvider.notifier).endGame();
  setState(() {
    _restoreSessionFuture = Future.value(null); // immediately hides the card
  });
},
```

---

### WR-03: `_onTick` countdown never shows "GO!" — the transition is instantaneous

**File:** `lib/features/game/game_session_notifier.dart:117–126`

**Issue:** On tick 5, `_countdownTick >= 5` triggers immediately — the phase becomes `playing` and `countdownSecondsRemaining` is implicitly 0, but no state is emitted with `countdownSecondsRemaining: 0` before the phase changes. The map screen only shows the countdown overlay when `session?.phase == GamePhase.countdown`. When the ticker fires the 5th tick, the phase jumps directly to `playing`, so the countdown overlay disappears without ever rendering "GO!". The "GO!" display string in `_buildCountdownOverlay` (`secondsRemaining > 0 ? '$secondsRemaining' : 'GO!'`) is dead code.

**Fix:** Emit a state with `phase: countdown` and `countdownSecondsRemaining: 0` (the "GO!" frame) and then transition to playing one tick later:
```dart
// In _onTick, when _countdownTick >= 5:
if (_countdownTick == 5) {
  state = AsyncData(current.copyWith(countdownSecondsRemaining: 0));
  // Transition to playing on the next tick
} else if (_countdownTick == 6) {
  _stopwatch.start();
  state = AsyncData(current.copyWith(
    phase: GamePhase.playing,
    countdownSecondsRemaining: 0,
  ));
}
```

---

### WR-04: `submitTyping` does not normalize the `normalized` value to uppercase

**File:** `lib/features/game/game_session_notifier.dart:204, 211`

**Issue:** `submitTyping` computes `normalized = input.trim()` without uppercasing. The name comparison `s.name.toUpperCase() == normalized` works only if `normalized` is already uppercase. The postal code comparison `s.postal == normalized` works only if the caller sends uppercase (e.g., 'GA'). `SpeedTypingScreen._onSubmit` correctly uppercases before calling `submitTyping`, so the production path works. But `submitTyping` is a public method on `GameSessionNotifier` — callers (including future test authors or other screens) who pass mixed-case input will get silent misses. The docstring says `s.name.toUpperCase() == normalized` but `normalized` is not guaranteed to be uppercase.

**Fix:**
```dart
final normalized = input.trim().toUpperCase();
```
This is a one-character change and makes the function's behavior match its documentation and independent of caller discipline.

---

## Info

### IN-01: `context.go('/type', extra: saved.session.mode)` — `extra` is silently ignored

**File:** `lib/features/home/home_screen.dart:60`

**Issue:** When restoring a Speed Typing session, `context.go('/type', extra: saved.session.mode)` passes a `GameMode` extra. The `/type` route builder in `app.dart` (line 40) is `const SpeedTypingScreen()` — it ignores `state.extra` entirely. The `extra` is harmlessly discarded. This is dead code that could mislead future maintainers into thinking `SpeedTypingScreen` respects the `extra` parameter.

**Fix:** Remove the `extra` argument:
```dart
context.go('/type'); // SpeedTypingScreen always uses GameMode.speedTyping
```

---

### IN-02: Math challenge PRNG uses wall-clock milliseconds — low entropy within a second

**File:** `lib/features/map/completion_screen.dart:356–358`

**Issue:** The math challenge seed is `DateTime.now().millisecondsSinceEpoch`. Within a single frame (< 16ms), this seed is identical, producing the same `_a` and `_b` across all instances opened in that window. More importantly, `_a` and `_b` are derived by modular arithmetic on the same seed integer: `_a = 3 + seed % 7` and `_b = 2 + (seed ~/ 13) % 8`. The two values are highly correlated (both determined by one integer). For a child-lock, this level of randomness is acceptable, but the values cycle with a period of `lcm(7, 8, 13) = 728ms`, meaning the sum `_a + _b` cycles through only ~50 distinct values.

**Fix:** Use `dart:math Random()` without a fixed seed:
```dart
final rng = math.Random();
_a = 3 + rng.nextInt(7); // 3–9
_b = 2 + rng.nextInt(8); // 2–9
```

---

### IN-03: `_FakeGameSessionNotifier.startGame` in typing screen tests does not start the ticker

**File:** `test/features/typing/speed_typing_screen_test.dart:153–155`

**Issue:** `_FakeGameSessionNotifier.startGame` sets `state = AsyncData(_initialSession.copyWith(phase: GamePhase.playing))` but does not start the `_NoOpTicker`. Since `_NoOpTicker.start` is a no-op anyway, this is harmless at runtime. However, the fake `startGame` bypasses the `_gameStartRequested` guard in `SpeedTypingScreen._maybeStartGame`. If the initial session is already `GamePhase.playing`, `_maybeStartGame` returns early (phase is not idle/completed), so `startGame` is never called from the screen — the test `_FakeGameSessionNotifier.startGame` only fires when called explicitly. This is a subtle asymmetry: the fake notifier's `startGame` side-effects differ from the real one's (no stopwatch start, no ticker), but since the tests don't exercise timing-sensitive paths, test reliability is not affected.

**Fix:** Document the limitation:
```dart
@override
void startGame(GameMode mode, {bool skipCountdown = false}) {
  // Fake: skips stopwatch and ticker; only advances phase to playing.
  state = AsyncData(_initialSession.copyWith(phase: GamePhase.playing));
}
```

---

_Reviewed: 2026-06-02T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
