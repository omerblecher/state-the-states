---
phase: 04-full-play-loop
reviewed: 2026-06-01T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - lib/app.dart
  - lib/features/game/game_hud.dart
  - lib/features/game/state_tray.dart
  - lib/features/home/home_screen.dart
  - lib/features/map/completion_screen.dart
  - lib/features/map/map_screen.dart
  - test/features/home/home_screen_test.dart
  - test/features/map/completion_screen_test.dart
  - test/features/map/map_screen_test.dart
  - test/features/map/state_tray_test.dart
findings:
  critical: 3
  warning: 5
  info: 3
  total: 11
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-06-01T00:00:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 4 delivers the full play loop: `MapScreen` game logic, `GameHud`, `StateTray`,
`HomeScreen` with repository-backed score display, `CompletionScreen` with star rating and
confetti, and corresponding tests. The architecture is solid — Riverpod codegen, correct
`PopScope` guard, `GameLifecycleObserver` wiring, and `OverlayEntry` cleanup are all
implemented. However three correctness bugs were found that will cause incorrect behavior
at runtime, along with five quality issues that erode maintainability or reliability.

---

## Critical Issues

### CR-01: `/complete` route crashes on direct navigation (unguarded cast)

**File:** `lib/app.dart:30`
**Issue:** The `/complete` route casts `state.extra` unconditionally:
```dart
final extra = state.extra as Map<String, dynamic>;
```
If `state.extra` is `null` (direct link, browser back/forward, or any navigation to
`/complete` without the `extra` map), this throws a `TypeError` at runtime and crashes the
app. The `/play` route handles the same pattern safely with a nullable cast (`as GameMode?`).
**Fix:**
```dart
GoRoute(
  path: '/complete',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    if (extra == null) return const HomeScreen(); // graceful fallback
    return CompletionScreen(
      session: extra['session'] as GameSession,
      previousBest: extra['previousBest'] as int?,
    );
  },
),
```

---

### CR-02: Star-rating logic in `HomeScreen` is inconsistent with `CompletionScreen`

**File:** `lib/features/home/home_screen.dart:187-192`
**Issue:** `_starsForScore` uses hardcoded absolute thresholds to rate a stored best score:
```dart
int _starsForScore(int? score) {
  if (score == null) return 0;
  if (score <= 80) return 3;
  if (score <= 150) return 2;
  return 1;
}
```
`CompletionScreen` (and its exported `computeStarCount`) rates the *current* game relative
to the *previous* best using a ±20% envelope:
```dart
if (score < previousBest) return 3;
if (score <= (previousBest * 1.20).ceil()) return 2;
return 1;
```
These two systems are completely different. A player who earns 3 stars on the completion
screen (beating their previous best of 200 with a score of 195) will see only 1 star on
the home screen (because 195 > 150). The home screen stars are therefore meaningless and
misleading. This likely stems from a placeholder that was never wired to the real formula.
**Fix:** Replace `_starsForScore` with the same relative formula, threading
`previousBest` from the stored score to derive an implied "relative quality" rating.
Since the home screen only has one data point (the stored best), the simplest correct
approach is to show stars based on the stored score alone using a known absolute scale
derived from game design, OR remove the star display from the home screen entirely and
only show the numeric best. If stars must be shown, unify on the `computeStarCount`
contract — exposed already as a top-level function in `completion_screen.dart`:
```dart
// _starsForScore replacement: not relative (no previous-previous best stored),
// so use absolute thresholds from game design — but document them explicitly.
// OR: remove stars from the home screen and only show the numeric best.
```

---

### CR-03: Force-unwrap (`!`) on provider value in `_advanceToNextPostal` can throw

**File:** `lib/features/map/map_screen.dart:255`
**Issue:**
```dart
final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
```
The `!` force-unwrap throws a `Null check operator used on a null value` exception if the
`gameSessionProvider` has been invalidated or is in an error state at the moment the last
state is placed. This can happen if, for example, the user places the 50th state very
quickly after a lifecycle event triggers provider disposal. In that case the overlay
animation completes, `_advanceToNextPostal` runs, and the app crashes instead of
navigating to the completion screen.
**Fix:**
```dart
final sessionBeforeComplete = ref.read(gameSessionProvider).value;
if (sessionBeforeComplete == null) return; // provider not ready — abort navigation
final repo = await ref.read(highScoreRepositoryProvider.future);
final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
await ref.read(gameSessionProvider.notifier).completeGame();
if (!mounted) return;
final completedSession = ref.read(gameSessionProvider).value;
if (completedSession == null) return;
context.go('/complete', extra: {
  'session': completedSession,
  'previousBest': previousBest,
});
```

---

## Warnings

### WR-01: `kPinAnchor` duplicated as a literal in `_handleDrop` — divergence risk

**File:** `lib/features/map/map_screen.dart:284`
**Issue:** The drop-coordinate recovery uses a hard-coded literal:
```dart
final rawScene = _toSceneFromGlobal(details.offset + const Offset(45, 70));
```
`StateTray.kPinAnchor` is declared as `static const kPinAnchor = Offset(45, 70)` and its
comment documents it as the load-bearing constant for the drop-coordinate math. The
`map_screen.dart` literal is a copy that will silently diverge if `kPinAnchor` is ever
adjusted (e.g. to change card dimensions). The comment above the line names the constant
but does not reference it.
**Fix:**
```dart
final rawScene = _toSceneFromGlobal(
    details.offset + StateTray.kPinAnchor);
```

---

### WR-02: Side effects (`_states =` and `_startSequence`) inside `build()`

**File:** `lib/features/map/map_screen.dart:530-532`
**Issue:**
```dart
_states = states;
_startSequence(states);
```
Both statements are called inside `_buildMapStack`, which is called from `build()`. Mutating
instance state from within `build()` is an anti-pattern in Flutter. `setState` calls inside
`build()` are forbidden; direct field mutations are not, but they create identical hazards:
if the framework rebuilds the widget twice in the same frame (which it may do during hot
reload, widget tree inflation, or certain state transitions), `_startSequence` is guarded
by `_sequenceInitialized` but `_states` is re-set on every call. If a frame rebuild occurs
between `_states` being set and `_handleDrop` using it, the data is always consistent; but
a future refactor could break this invariant silently.
**Fix:** Move the `_states` assignment and `_startSequence` call to a location where they
run exactly once and not inside `build()`. For example, call them from
`_fitMapToScreen()` after the provider data is first available, or wire them through a
`ref.listen` in `initState`:
```dart
// In initState, after provider data resolves:
ref.listenManual(stateDataProvider, (_, next) {
  if (next.hasValue && !_sequenceInitialized) {
    _states = next.value!.states;
    _startSequence(next.value!.states);
  }
});
```

---

### WR-03: `_toggleMute` silently drops the `Future` returned by `setMuted`

**File:** `lib/features/map/map_screen.dart:219-225`
**Issue:**
```dart
void _toggleMute() {
  try {
    ref.read(audioServiceProvider).setMuted(!_isMuted);
  } catch (_) {
    // StubAudioService may not implement setMuted — silence it.
  }
  setState(() => _isMuted = !_isMuted);
}
```
`AudioService.setMuted` returns `Future<void>`. The call is not `await`-ed, so any
asynchronous error (e.g. from `RealAudioService`) is silently discarded. The `try/catch`
only covers synchronous throws. The comment is also stale — `StubAudioService` does
implement `setMuted` (it is required by the `AudioService` interface). The mute state
`_isMuted` is toggled immediately regardless of whether the audio service call succeeded,
meaning the UI and audio can desync if the async call fails.
**Fix:** Convert the method to `async` and `await` the call, or at minimum attach an
error handler:
```dart
Future<void> _toggleMute() async {
  try {
    await ref.read(audioServiceProvider).setMuted(!_isMuted);
    setState(() => _isMuted = !_isMuted);
  } catch (e) {
    // Log or show a toast — do not toggle UI state on failure.
    debugPrint('AudioService.setMuted failed: $e');
  }
}
```
Note: `onPause`, `onMuteToggle` callbacks on `GameHud` are `VoidCallback?`, so if
`_toggleMute` becomes async you also need to update the field signature on `GameHud` or
use `() { _toggleMute(); }` at the call site.

---

### WR-04: `FutureBuilder` in `_ModeCard` receives a new `Future` on every parent rebuild

**File:** `lib/features/home/home_screen.dart:258-300`
**Issue:** `_ModeCard.bestScoreFuture` is passed from `_HomeScreenState._buildBody`:
```dart
bestScoreFuture: repo.getBestScore(GameMode.learn),
```
Every time `_HomeScreenState` rebuilds (e.g. on orientation change, theme change, or any
`setState`), `_buildBody` creates a new `Future<int?>` object and passes it to `_ModeCard`
via `didUpdateWidget`. `FutureBuilder` treats a changed `future` reference as "restart the
future" and resets to `ConnectionState.waiting`, briefly flashing "Not played" for all
four mode cards before re-resolving. Since `_ModeCard` is a `StatefulWidget`, Flutter
calls `didUpdateWidget` when `widget.bestScoreFuture` changes. This is the canonical
"FutureBuilder inside a StatefulWidget receiving a new future on rebuild" pitfall.
**Fix:** Cache the futures in `_ModeCardState.initState()` (or deduplicate at the
`_HomeScreenState` level):
```dart
class _ModeCardState extends State<_ModeCard> with ... {
  late final Future<int?> _cachedFuture;

  @override
  void initState() {
    super.initState();
    _cachedFuture = widget.bestScoreFuture; // cache once
    ...
  }
  // Use _cachedFuture in FutureBuilder, not widget.bestScoreFuture
}
```

---

### WR-05: `_isNewPb` is always `false` when `previousBest == null` (first game)

**File:** `lib/features/map/completion_screen.dart:55-56`
**Issue:**
```dart
if (prev == null) {
  _isNewPb = false;  // first game — no confetti
  _starCount = 3;
}
```
The first-ever game earns 3 stars but shows no "New Personal Best!" badge and no confetti.
This is arguably inconsistent with the user experience expectation: completing the game for
the first time *is* a personal best (from infinity to a finite score), and the absence of
any celebration for the very first win is a poor experience for new players — especially
the children aged 8+ who are the target audience.

The test at `completion_screen_test.dart:45` explicitly asserts `findsNothing` for the PB
badge on first game, showing the test was written to match the current (questionable)
behavior rather than the intended UX. Whether intentional or an oversight should be
clarified before shipping.

**Fix (if first-game celebration is desired):**
```dart
if (prev == null) {
  _isNewPb = true;  // first game is always a new personal best
  _starCount = 3;
}
```
If the design decision is intentional (no confetti on first play), add an explicit comment
and update the test name to remove "no PB badge" ambiguity.

---

## Info

### IN-01: Hardcoded `kDebugMode` access workaround in `build()` is dead code

**File:** `lib/features/map/map_screen.dart:485-488`
**Issue:**
```dart
assert(() {
  kDebugMode;
  return true;
}());
```
This `assert` block exists solely to silence an "unused variable" lint for `kDebugMode`.
The `kDebugMode` import is used nowhere in the production code path — the `/spike` route
is in `app.dart`, not `map_screen.dart`. This is dead code that adds cognitive noise.
**Fix:** Remove both the `import 'package:flutter/foundation.dart' show kDebugMode;` and
the `assert` block, or use the import in a real conditional (e.g., a debug-only overlay).

---

### IN-02: Unused `_noOp` default callback on `StateTray.onHintPressed`

**File:** `lib/features/game/state_tray.dart:36`
**Issue:**
```dart
this.onHintPressed = _noOp,
```
The `onHintPressed` callback is wired in `map_screen.dart` with a no-op lambda
`() {}` (Phase 5 placeholder), rather than `StateTray._noOp`. The static `_noOp` on the
class duplicates what the default `() {}` parameter already provides, and it prevents the
caller from passing `null` to disable the button (which would require a nullable type
`VoidCallback?`). The hint button always appears active even with 0 hints if the caller
forgets to check `hintsRemaining`.
**Fix:** Either make `onHintPressed` nullable (`VoidCallback?`) and disable the button
when null/hintsRemaining==0, or document that `_noOp` is intentional as the non-null
default. In `map_screen.dart`, consider disabling the hint button when
`session?.hintsRemaining == 0` by passing `null` to `onHintPressed`.

---

### IN-03: `TODO` in production test file marks unfinished test coverage

**File:** `test/features/map/map_screen_test.dart:57-59`
**Issue:**
```dart
// TODO(phase-3): Expose _controller via @visibleForTesting for precise scale
// assertions once entry(2,2) sync is verified via SpikeMapScreen (Criterion 4).
```
This TODO has been carried into phase 4 unchanged (the comment references phase-3). Precise
scale assertions for the zoom buttons remain untested. The zoom tests only verify
"no crash" — they don't assert any scale change occurred. The `TODO` should be resolved or
tracked as a known gap before shipping.
**Fix:** Either implement the `@visibleForTesting` exposure and add the scale assertion in
this phase, or move the TODO to a tracking issue and remove it from the test file to keep
the test file clean.

---

_Reviewed: 2026-06-01T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
