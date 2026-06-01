---
phase: 04-full-play-loop
plan: 01
subsystem: ui
tags: [flutter, go_router, riverpod, game-mode, routing, completion-screen]

# Dependency graph
requires:
  - phase: 03-map-render
    provides: MapScreen with TransformationController, GameMode enum, GameSession, HighScoreRepository
provides:
  - /play GoRoute extracts GameMode from state.extra and passes to MapScreen
  - /complete GoRoute routes to CompletionScreen with session + previousBest
  - CompletionScreen stub with computeStarCount (D-11 formula) and navigation CTAs
  - Wave 0 test stubs for home_screen_test, completion_screen_test, state_tray_test
affects: [04-02-state-tray, 04-03-game-hud, 04-05-completion-ui, 04-06-home-screen]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - GoRouter state.extra cast pattern for typed route params (GameMode, Map<String,dynamic>)
    - computeStarCount pure function exported alongside widget for unit-testability
    - Wave 0 test stub pattern — compilable placeholder tests with skip:true or passing placeholder assertion

key-files:
  created:
    - lib/features/map/completion_screen.dart
    - test/features/map/completion_screen_test.dart
    - test/features/home/home_screen_test.dart
    - test/features/map/state_tray_test.dart
  modified:
    - lib/app.dart
    - lib/features/map/map_screen.dart

key-decisions:
  - "MapScreen.mode changed from GameMode? nullable to GameMode non-nullable with default GameMode.learn — preserves backward-compat for existing const MapScreen() calls (Risk 7 from RESEARCH.md)"
  - "state_tray_test.dart uses skip:true (bool) not skip:'string' — Dart 3.12/Flutter 3.44 testWidgets skip param is bool? not Object?"
  - "state_tray_test.dart omits state_tray.dart import — missing file causes compile failure even with skip; file reference replaced with comment until Plan 03 creates state_tray.dart"

patterns-established:
  - "Route extra typing: GoRoute builder uses `state.extra as T? ?? default` for enum extras, `state.extra as Map<String,dynamic>` for compound objects"
  - "computeStarCount: top-level exported function adjacent to widget file enables pure unit tests without widget pump"

requirements-completed: [HOME-01, HOME-02, SCORE-06, SCORE-07]

# Metrics
duration: 15min
completed: 2026-06-01
---

# Phase 4 Plan 01: Routing Foundation + Wave 0 Test Stubs Summary

**GoRouter wired for GameMode-typed /play route and /complete route; CompletionScreen stub with D-11 star formula; three Wave 0 test files ensuring Nyquist compliance for all subsequent waves**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-01T14:10:00Z
- **Completed:** 2026-06-01T14:25:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `/play` GoRoute now extracts `GameMode` from `state.extra` with fallback to `GameMode.learn`, enabling mode-aware game sessions from Phase 4 forward
- `/complete` GoRoute added: accepts `Map<String,dynamic>` extra with `session` + `previousBest`, routes to `CompletionScreen`
- `CompletionScreen` stub created with `computeStarCount` (D-11 formula), confetti PB overlay, Back-to-Menu and Play-Again CTAs
- Three Wave 0 test files created so all subsequent waves compile against real test files from day one

## Task Commits

1. **Task 1: Update app.dart routing and MapScreen constructor** - `edbf8e6` (feat)
2. **Task 2: CompletionScreen stub + Wave 0 test files** - `d98690b` (feat)

## Files Created/Modified

- `lib/app.dart` — /play GameMode extraction, /complete route added, imports for GameMode/GameSession/CompletionScreen
- `lib/features/map/map_screen.dart` — mode field changed from `GameMode? mode` to `GameMode mode` with default `GameMode.learn`
- `lib/features/map/completion_screen.dart` — stub CompletionScreen with computeStarCount, confetti overlay, Back to Menu + Play Again buttons
- `test/features/map/completion_screen_test.dart` — 4 unit tests for computeStarCount (null/PB/within-20%/above-20% boundaries)
- `test/features/home/home_screen_test.dart` — compilable stub with MockHighScoreRepository override, placeholder assertion
- `test/features/map/state_tray_test.dart` — skipped stub test (StateTray not yet implemented)

## Decisions Made

- `MapScreen.mode` changed to non-nullable `GameMode mode = GameMode.learn` — preserves backward-compat for `const MapScreen()` calls in existing tests (Risk 7 from RESEARCH.md)
- `state_tray_test.dart` uses `skip: true` (bool) instead of a string — Flutter 3.44 / Dart 3.12 `testWidgets` skip parameter is `bool?`; passing a string caused compile failure
- `state_tray_test.dart` omits the `state_tray.dart` import entirely — missing file causes compile failure in Dart even with `skip: true`; plan's "forward reference" approach is not viable in strict Dart compilation; import replaced with comment describing future Plan 03 work

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] state_tray_test.dart skip parameter and missing import**
- **Found during:** Task 2 verification
- **Issue:** Plan spec called for `skip: 'StateTray not yet implemented...'` (string) but Flutter 3.44 testWidgets `skip` is `bool?` not `Object?`; also the import of non-existent `state_tray.dart` caused compile failure even with skip
- **Fix:** Changed `skip` to `true` (bool); removed the unresolvable import and body references to `StateTray`, replaced with comment explaining Plan 03 will add the full test
- **Files modified:** `test/features/map/state_tray_test.dart`
- **Verification:** `flutter test test/features/map/state_tray_test.dart` exits 0 with test skipped
- **Committed in:** d98690b (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - compile bug in test stub)
**Impact on plan:** Fix necessary for compilability. Test intent preserved — skip still marks the test as pending Plan 03 work. No scope creep.

## Issues Encountered

None beyond the state_tray_test compile issue documented above.

## Known Stubs

- `lib/features/map/completion_screen.dart` — CompletionScreen is a stub: full star animation, elapsed time display, and detailed score breakdown are added in Plan 04-05
- `test/features/home/home_screen_test.dart` — placeholder assertion `expect(true, isTrue)` with comment "assertions added in Plan 06"
- `test/features/map/state_tray_test.dart` — entire test body skipped; real assertions added in Plan 03

## Next Phase Readiness

- Wave 1 complete: routing foundation is solid, all Wave 2+ plans can navigate to `/play` with GameMode and `/complete` with session data
- Wave 0 test files exist and compile — Nyquist compliance satisfied
- Phase 4 Wave 2 (Plans 02–03: StateTray + GameHud) can begin

---
*Phase: 04-full-play-loop*
*Completed: 2026-06-01*
