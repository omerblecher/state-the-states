---
phase: 04-full-play-loop
plan: 02
subsystem: ui
tags: [flutter, riverpod, drag-drop, game-loop, map, custom-painter, pop-scope]

# Dependency graph
requires:
  - phase: 04-01
    provides: routing foundation (/play with GameMode extra, /complete route, CompletionScreen stub)
  - phase: 03-04
    provides: MapScreen ConsumerStatefulWidget, InteractiveViewer, UsaMapPainter, stateDataProvider
  - phase: 02-03
    provides: GameSessionNotifier (startGame, recordDrop, pauseGame, resumeGame, completeGame), GameLifecycleObserver
provides:
  - MapScreen with TickerProviderStateMixin and full game-loop wiring
  - _startSequence: DC-filtered shuffled 50-state postal sequence
  - GameLifecycleObserver mount/unmount (D-08) in initState/dispose
  - _handleDrop with stateHitTest and correct/incorrect routing
  - PopScope back-button guard with pause overlay
  - Countdown overlay (3-2-1-GO!) during GamePhase.countdown
  - Mode→showLabels/showName matrix (Learn/StatesMaster/GeographicalMaster/GrandMaster)
  - 6 new widget tests: 4 mode visibility + DragTarget + PopScope
affects: [04-03, 04-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "find.byType(PopScope) matches PopScope<dynamic> not PopScope<Object?> — use find.byWidgetPredicate((w) => w is PopScope) for reliable generic-type matching"
    - "find.byWidgetPredicate on CustomPaint with UsaMapPainter cast checks painter field values without requiring separate painter finder"

key-files:
  created:
    - .planning/phases/04-full-play-loop/04-02-SUMMARY.md
  modified:
    - lib/features/map/map_screen.dart
    - test/features/map/map_screen_test.dart

key-decisions:
  - "find.byType(PopScope) finds PopScope<dynamic> not PopScope<Object?> — use byWidgetPredicate for type-erased match"
  - "_startSequence called from _buildMapStack (inside stateDataProvider.when data callback) — guaranteed to run after MapData resolves, not from initState"

patterns-established:
  - "Mode→showLabels matrix: Learn=true, StatesMaster=false, GeographicalMaster=true, GrandMaster=false"
  - "PopScope generic type mismatch: always match via `w is PopScope` predicate, not byType"

requirements-completed: [DRAG-01, DRAG-04, DRAG-05, MODE-01, MODE-02, MODE-03, MODE-04, SCORE-06]

# Metrics
duration: 25min
completed: 2026-06-01
---

# Phase 4 Plan 02: MapScreen Game Loop Core Summary

**MapScreen transformed into a playable game screen: DC-filtered 50-state shuffle, DragTarget/_handleDrop routing to stateHitTest, PopScope pause guard, countdown overlay, mode→showLabels matrix, and 10 passing widget tests**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-01T14:25:00Z
- **Completed:** 2026-06-01
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- MapScreen now initializes a shuffled 50-state sequence (DC filtered), wires DragTarget to _handleDrop with stateHitTest, and guards the back button with PopScope + pause overlay
- GameLifecycleObserver is correctly mounted in initState and removed in dispose (D-08), pausing the session on AppLifecycleState.paused/.hidden
- 10 widget tests pass: 4 existing smoke tests + 4 mode visibility tests (showLabels via UsaMapPainter predicate) + DragTarget presence + PopScope presence

## Task Commits

1. **Task 1: MapScreen — sequence init, lifecycle observer, back-button guard, mode→label mapping** - `5f96ed6` (feat)
2. **Task 2: Add mode label visibility widget tests to map_screen_test.dart** - `7800cea` (feat)

## Files Created/Modified

- `lib/features/map/map_screen.dart` - Full game screen rewrite: TickerProviderStateMixin, _startSequence (DC filter + shuffle), GameLifecycleObserver, _handleDrop, PopScope, countdown overlay, pause overlay, mode→showLabels matrix
- `test/features/map/map_screen_test.dart` - 6 new tests: group 'MapScreen mode visibility' (4 modes), DragTarget presence, PopScope presence

## Decisions Made

- `find.byType(PopScope)` resolves to `PopScope<dynamic>` which does not match `PopScope<Object?>` in the widget tree — switched to `find.byWidgetPredicate((w) => w is PopScope)` for reliable matching regardless of type parameter
- `_startSequence` called from `_buildMapStack` (inside the `stateDataProvider.when` data callback) so it runs only after `MapData` resolves — not from `initState` where states are not yet available

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] PopScope test assertion fixed for generic type mismatch**
- **Found during:** Task 2 (running flutter test)
- **Issue:** `find.byType(PopScope)` found 0 widgets because it looks for `PopScope<dynamic>` but the tree contains `PopScope<Object?>` — a Dart generic type erasure mismatch in the test finder
- **Fix:** Changed assertion to `find.byWidgetPredicate((w) => w is PopScope)` which matches any PopScope regardless of type parameter
- **Files modified:** test/features/map/map_screen_test.dart
- **Verification:** flutter test exits 0, all 10 tests pass
- **Committed in:** 7800cea (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** One-line fix; no scope change. Generic type mismatch is a common Flutter test pitfall for generic widgets.

## Issues Encountered

- `find.byType(PopScope)` / `find.byType(DragTarget<String>)` generic type resolution differs between `PopScope<dynamic>` (found by byType) and `PopScope<Object?>` (in actual widget tree). Resolved by using `byWidgetPredicate` for PopScope. `DragTarget<String>` matched correctly via `find.byType(DragTarget<String>)` — only PopScope had the mismatch.

## Known Stubs

- `_buildStateTrayPlaceholder()` in map_screen.dart: renders a plain 120dp colored box with postal code text; replaced by real StateTray in Plan 03
- HUD row in `_buildMapStack`: `SizedBox(height: 48, child: ColoredBox(color: Colors.grey.shade800))` placeholder; replaced by GameHud in Plan 04
- `_advanceToNextPostal()`: skips fly-to-centroid animation; `_animateCorrectDrop` added in Plan 04

## Threat Flags

No new network endpoints, auth paths, or external trust boundaries introduced. All threat mitigations from plan threat model implemented: phase guard in `_handleDrop` blocks drops during countdown/paused/completed states.

## Next Phase Readiness

- Plan 03 can now build StateTray against the `_trayKey` / `_trayCardKey` GlobalKey fields and `kPinAnchor` constant that Plan 04 will wire
- Plan 04 (GameHud + fly animation) can replace the HUD placeholder row and `_buildStateTrayPlaceholder` with real widgets
- The `_handleDrop` method is fully wired — Plans 03/04 only need to replace placeholder outputs, not change the drop logic

---
*Phase: 04-full-play-loop*
*Completed: 2026-06-01*
