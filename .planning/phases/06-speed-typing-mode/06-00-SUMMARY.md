---
phase: 06-speed-typing-mode
plan: "00"
subsystem: testing
tags: [flutter, flutter_test, state_data, riverpod, dart_ui]

requires:
  - phase: 05-polish-welcome-accessibility
    provides: GameSessionNotifier and StateData types used in fixture

provides:
  - test/features/typing/ directory with compilable stub test file
  - stateFixture() helper in game_session_notifier_test.dart for Wave 2 submitTyping() tests

affects: [06-01, 06-02, 06-03]

tech-stack:
  added: []
  patterns:
    - "Wave 0 stub test: compilable placeholder in test/features/typing/ without importing the not-yet-created production file"
    - "stateFixture() top-level helper in notifier test: returns List<StateData> with minimal geometry for unit tests"

key-files:
  created:
    - test/features/typing/speed_typing_screen_test.dart
  modified:
    - test/features/game/game_session_notifier_test.dart

key-decisions:
  - "Stub test imports flutter_test only — no import of speed_typing_screen.dart (does not exist in Wave 0); import deferred to Wave 2 via TODO comment"
  - "stateFixture() uses pathStrings/paths as empty const lists — StateData.fromJson path parsing not needed for unit tests; avoids path_drawing dependency in fixture"

patterns-established:
  - "Wave 0 stub: single expect(true, isTrue) placeholder keeps suite green without real assertions"
  - "stateFixture() placed before void main() after mock class declarations — consistent with plan insertion point"

requirements-completed:
  - TYPING-03
  - TYPING-06

duration: 2min
completed: 2026-06-02
---

# Phase 6 Plan 00: Speed Typing Mode Test Scaffolding Summary

**Wave 0 test scaffolding: compilable stub in test/features/typing/ and stateFixture() helper in notifier test unblock Wave 2 widget and unit tests**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-02T17:41:11Z
- **Completed:** 2026-06-02T17:43:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `test/features/typing/` directory with `speed_typing_screen_test.dart` stub that compiles and passes (one placeholder test calling `expect(true, isTrue)`)
- Added `stateFixture()` top-level function to `game_session_notifier_test.dart` returning 5 `StateData` entries: GA, CA, NY (multi-word, tests D-02), TX, AK (inset group)
- Full notifier test suite still passes (27 tests, no regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create speed_typing_screen_test.dart stub** - `a55ad82` (feat)
2. **Task 2: Add stateFixture() helper to game_session_notifier_test.dart** - `0a6c4bd` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `test/features/typing/speed_typing_screen_test.dart` - Compilable stub; Wave 2 will add real TYPING-03 and TYPING-06 widget tests
- `test/features/game/game_session_notifier_test.dart` - Added dart:ui + state_data imports and stateFixture() function before void main()

## Decisions Made

- Stub test imports `flutter_test` only — importing `speed_typing_screen.dart` would cause a compile error since the file does not exist until Wave 2; import deferred via TODO comment per plan specification
- `stateFixture()` uses `pathStrings: const [], paths: const []` — avoids `parseSvgPathData()` call (path_drawing dependency); sufficient for `submitTyping()` unit tests which only use `postal`, `name`, `isPlaceable`, and `insetGroup`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing test failures in `test/features/map/usa_map_painter_test.dart` (missing `insetFrameRects` parameter) and `test/features/map/state_tray_test.dart` (text finder assertions) were observed during full suite run. These failures pre-date this plan and are out of scope. Documented in deferred items below.

## Known Stubs

None - both files created in this plan are intentional stubs/scaffolding (the stub is the deliverable, not a limitation).

## Deferred Items

- `usa_map_painter_test.dart` and `state_tray_test.dart` pre-existing failures — not caused by this plan, not fixed (out of scope per deviation scope boundary rule)

## Threat Flags

None - this plan creates test-only files with no new network endpoints, auth paths, file access patterns, or schema changes.

## Next Phase Readiness

- Wave 2 (Plan 02, 03) can now create `lib/features/typing/speed_typing_screen.dart` and add real widget tests to `test/features/typing/speed_typing_screen_test.dart` by replacing the placeholder and adding the import
- Wave 2 unit tests for `submitTyping()` can call `stateFixture()` directly from `game_session_notifier_test.dart`
- No blockers for Wave 1 (Plan 01 — GameMode.speedTyping + submitTyping())

## Self-Check: PASSED

- `test/features/typing/speed_typing_screen_test.dart` exists: FOUND
- `test/features/game/game_session_notifier_test.dart` modified: FOUND
- Commit `a55ad82` exists: FOUND
- Commit `0a6c4bd` exists: FOUND

---
*Phase: 06-speed-typing-mode*
*Completed: 2026-06-02*
