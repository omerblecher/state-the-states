---
phase: 04-full-play-loop
plan: 04
subsystem: ui
tags: [flutter, game-hud, state-tray, overlay-animation, fly-to-centroid, widget-test]

# Dependency graph
requires:
  - phase: 04-02
    provides: MapScreen base with _handleDrop, _advanceToNextPostal, _startSequence
  - phase: 04-03
    provides: StateTray widget with kPinAnchor, triggerBounce(), GlobalKey discipline
provides:
  - GameHud stateless widget: score, elapsed timer, progress bar, mute/pause buttons
  - MapScreen with real GameHud in Row 1 and StateTray in AnimatedSwitcher Row 3
  - _animateCorrectDrop: 500ms fly-to-centroid OverlayEntry with mounted guard
  - _centroidToScreen: scene-to-screen coordinate transform via MatrixUtils
  - _buildTokenPreview: token card widget for overlay animation
  - 12 map_screen widget tests all passing (2 new: GameHud, AnimatedSwitcher)
affects: [04-05, 04-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GameHud: 48dp fixed height, grey.shade800 background, FontFeature.tabularFigures() for MM:SS timer"
    - "_animateCorrectDrop: OverlayEntry + AnimationController lifecycle — dispose in whenComplete with mounted guard; _activeOverlay?.remove() in dispose() (Pitfall 4)"
    - "_centroidToScreen: MatrixUtils.transformPoint(matrix, sceneCentroid) + box.localToGlobal(viewportLocal)"
    - "AnimatedSwitcher FadeTransition only (no SlideTransition) — SlideTransition moves hit-test area making Draggable unreachable mid-transition"
    - "GlobalKey<StateTrayState> for _trayKey enables triggerBounce() call on incorrect drop"
    - "UsaMapPainter predicate cast: use 'is UsaMapPainter' guard before 'as UsaMapPainter' — avoids TypeError from _ShapeBorderPainter in widget tree"

key-files:
  created:
    - lib/features/game/game_hud.dart
    - .planning/phases/04-full-play-loop/04-04-SUMMARY.md
  modified:
    - lib/features/map/map_screen.dart
    - test/features/map/map_screen_test.dart

key-decisions:
  - "GameHud uses hardcoded string literals (no l10n dependency in Phase 4)"
  - "_animateCorrectDrop disposes AnimationController in whenComplete with mounted guard — prevents setState after dispose"
  - "_buildMapStack receives GameSession? as parameter from build() to avoid double ref.watch call"
  - "Rule 1 auto-fix: mode visibility tests used unsafe 'as UsaMapPainter?' cast; replaced with 'is UsaMapPainter' type check to prevent TypeError from coexisting painters"

requirements-completed: [DRAG-02, DRAG-03, DRAG-04, DRAG-05, SCORE-03, SCORE-04]

# Metrics
duration: 7min
completed: 2026-06-01
---

# Phase 4 Plan 04: GameHud + Fly-to-Centroid Overlay Summary

**GameHud widget and full MapScreen feedback loop wired: real HUD shows score/timer/progress, StateTray replaces placeholder, fly-to-centroid OverlayEntry animates correct drops, _advanceToNextPostal navigates to /complete on game completion**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-06-01T12:44:57Z
- **Completed:** 2026-06-01
- **Tasks:** 2
- **Files modified:** 4 (2 modified, 2 created)

## Accomplishments

- `GameHud` stateless widget created — 48dp fixed height, grey.shade800, score label, 6dp amber LinearProgressIndicator, MM:SS tabular-digit timer, 48×48 mute/pause icon buttons with Semantics
- MapScreen Row 1 SizedBox placeholder replaced with real `GameHud(score:, elapsed:, matchedCount:, totalFlags:50, onPause:, isMuted:, onMuteToggle:)`
- MapScreen Row 3 `_buildStateTrayPlaceholder` replaced with real `StateTray` inside `AnimatedSwitcher` (FadeTransition only)
- `_centroidToScreen` helper added — converts scene centroid via `MatrixUtils.transformPoint` to global screen offset
- `_animateCorrectDrop` added — creates 500ms OverlayEntry (position/scale/opacity), inserts via `Overlay.of(context).insert()`, disposes `AnimationController` in `whenComplete` with `if (mounted)` guard, calls `_activeOverlay?.remove()` in `dispose()` (Pitfall 4 / T-04-05)
- `_buildTokenPreview` added — simple postal-abbreviation card used in fly animation
- `_handleDrop` correct path updated to call `_animateCorrectDrop` (was bare `_advanceToNextPostal`)
- `_handleDrop` incorrect path now calls `_trayKey.currentState?.triggerBounce()`
- `_trayKey` re-typed from `GlobalKey` to `GlobalKey<StateTrayState>` enabling `triggerBounce()` call
- `_advanceToNextPostal` unchanged — already navigated to `/complete` with `{session, previousBest}` extra
- 12 map_screen tests pass; 114 total tests pass (no regressions)

## Task Commits

1. **Task 1: Create GameHud widget** - `f076058` (feat)
2. **Task 2: RED — failing tests for GameHud and AnimatedSwitcher** - `e4aa7a8` (test)
3. **Task 2: GREEN — wire GameHud + StateTray; fly-to-centroid overlay** - `4877ccc` (feat)

## Files Created/Modified

- `lib/features/game/game_hud.dart` — GameHud stateless widget; 126 lines
- `lib/features/map/map_screen.dart` — imports game_hud/state_tray/game_session; real GameHud Row 1; StateTray AnimatedSwitcher Row 3; _centroidToScreen; _animateCorrectDrop; _buildTokenPreview; updated _handleDrop; _trayKey typed as GlobalKey<StateTrayState>
- `test/features/map/map_screen_test.dart` — added game_hud.dart import; 2 new tests (GameHud, AnimatedSwitcher); fixed mode-visibility predicate cast (Rule 1)

## Decisions Made

- `GameHud` has no l10n dependency — hardcoded string literals (Phase 4 scope)
- `_buildMapStack` receives `GameSession?` as a parameter to avoid calling `ref.watch` twice on the same provider in one build cycle
- `AnimatedSwitcher` uses `FadeTransition` only — `SlideTransition` would move the hit-test area, making `Draggable` unreachable during transition

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mode visibility test cast TypeError when StateTray added to tree**
- **Found during:** Task 2 GREEN (full test run)
- **Issue:** `(w.painter as UsaMapPainter?)?.showLabels` threw `_TypeError: type '_ShapeBorderPainter' is not a subtype of type 'UsaMapPainter?'` — ElevatedButton inside StateTray adds `_ShapeBorderPainter` to the widget tree, which the widgetPredicate evaluated
- **Fix:** Replaced `as UsaMapPainter?` cast with `is UsaMapPainter &&` type guard before cast
- **Files modified:** `test/features/map/map_screen_test.dart`
- **Commit:** `4877ccc`

## Known Stubs

None. GameHud is fully wired with live session data. StateTray is fully wired. `_advanceToNextPostal` navigates to `/complete`. Hint button in StateTray calls `() {}` (no-op) — this is intentional and documented: Phase 5 wires hint zoom.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| T-04-05 mitigated | lib/features/map/map_screen.dart | OverlayEntry disposed in both `dispose()` (_activeOverlay?.remove()) and `_animateCorrectDrop` whenComplete — T-04-05 threat fully mitigated |

## Self-Check: PASSED

- `lib/features/game/game_hud.dart` exists ✓
- `lib/features/map/map_screen.dart` updated with GameHud + StateTray + _animateCorrectDrop ✓
- `test/features/map/map_screen_test.dart` has 2 new tests + mode-visibility fix ✓
- Commits `f076058`, `e4aa7a8`, `4877ccc` exist ✓
- 12/12 map_screen tests pass; 114/114 full suite passes ✓

---
*Phase: 04-full-play-loop*
*Completed: 2026-06-01*
