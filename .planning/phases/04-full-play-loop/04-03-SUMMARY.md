---
phase: 04-full-play-loop
plan: 03
subsystem: ui
tags: [flutter, drag-drop, state-tray, animation, game-mode, widget-test]

# Dependency graph
requires:
  - phase: 04-01
    provides: game_mode.dart (GameMode enum — learn, statesMaster, geographicalMaster, grandMaster)
provides:
  - StateTray StatefulWidget with bounce animation (500ms elasticOut), mode-driven card face, Draggable<String> integration
  - StateTrayState.triggerBounce() public method — called by MapScreen on incorrect drop
  - StateTray.kPinAnchor = Offset(45, 70) compile-time constant — matches MapScreen drop-coordinate math
  - GlobalKey discipline: cardKey on Draggable.child only, never feedback/childWhenDragging
  - 7 widget tests covering MODE-01 through MODE-04, hint button count, Draggable.data, triggerBounce smoke
affects: [04-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "StateTray mode switch: learn/geographicalMaster=28sp abbreviation, statesMaster=17sp state name, grandMaster=palette[sequenceIndex%6] color fill"
    - "kPinAnchor=Offset(45,70): width 90 → cx=45; card height 60 + triangle 10 → tip y=70"
    - "GlobalKey on Draggable.child only — feedback and childWhenDragging call _cardShell() with no key to prevent duplicate-GlobalKey crash during drag"

key-files:
  created:
    - lib/features/game/state_tray.dart
    - .planning/phases/04-full-play-loop/04-03-SUMMARY.md
  modified:
    - test/features/map/state_tray_test.dart

key-decisions:
  - "StateTray is a direct port of FlagTray with SvgPicture replaced by mode-driven _cardFace() switch"
  - "triggerBounce() is public (exposed on StateTrayState) so MapScreen can call _trayKey.currentState?.triggerBounce() on incorrect drop"

requirements-completed: [DRAG-03, DRAG-04, DRAG-05, MODE-01, MODE-02, MODE-03, MODE-04]

# Metrics
duration: 3min
completed: 2026-06-01
---

# Phase 4 Plan 03: StateTray Widget Summary

**StateTray: draggable state token widget — port of FlagTray with mode-driven card face (abbreviation, state name, or solid palette color) replacing SvgPicture; 7 widget tests green**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-01T12:39:37Z
- **Completed:** 2026-06-01
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `StateTray` and `StateTrayState` created in `lib/features/game/state_tray.dart` — direct port of FlagTray with mode-driven card face replacing SvgPicture
- `kPinAnchor = Offset(45, 70)` compile-time constant matches the drop-coordinate math already wired in MapScreen._handleDrop
- GlobalKey discipline correct: `cardKey` on `Draggable.child` only; `_cardShell()` called with no key on feedback and childWhenDragging
- `triggerBounce()` public method on `StateTrayState` — 500ms elasticOut animation on wrong drop
- Mode matrix: `learn`/`geographicalMaster` → 28sp abbreviation; `statesMaster` → 17sp state name; `grandMaster` → solid palette[sequenceIndex % 6] color
- 7 widget tests all pass: 4 mode visibility tests (MODE-01 through MODE-04), hint button count, Draggable.data, triggerBounce smoke
- Full test suite (112 tests) passes — no regressions

## Task Commits

1. **Task 1: StateTray widget (port of FlagTray with mode-driven card face)** - `577a4ed` (feat)
2. **Task 2: Fill state_tray_test.dart with MODE-01 through MODE-04 and bounce tests** - `a41da6d` (feat)

## Files Created/Modified

- `lib/features/game/state_tray.dart` — StateTray + StateTrayState: bounce animation, kPinAnchor, mode-driven _cardFace, Draggable<String>, _DownTriangle clipper, hint button
- `test/features/map/state_tray_test.dart` — Full replacement of skipped stub: 7 widget tests covering all 4 game modes, hint button, Draggable.data, triggerBounce

## Decisions Made

- `StateTray` is a direct port of `FlagTray` — SvgPicture replaced by a `switch` on `GameMode` in `_cardFace()`; no other structural changes needed
- `triggerBounce()` exposed as public on `StateTrayState` so `MapScreen` can call `_trayKey.currentState?.triggerBounce()` on an incorrect drop without bypassing the `GlobalKey<StateTrayState>` type

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Both files are fully implemented with no placeholder values.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes. The `Draggable<String>.data` field carries only the widget's own `postal` prop (set by MapScreen from verified JSON data) — no external user-text-input path.

## Self-Check: PASSED

- `lib/features/game/state_tray.dart` exists ✓
- `test/features/map/state_tray_test.dart` updated ✓  
- Commits `577a4ed` and `a41da6d` exist ✓
- 7/7 tests pass, 112/112 full suite pass ✓

---
*Phase: 04-full-play-loop*
*Completed: 2026-06-01*
