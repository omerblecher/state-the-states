---
phase: 06-speed-typing-mode
plan: "01"
subsystem: game
tags: [flutter, dart, riverpod, game_mode, enum, tdd, unit_test]

requires:
  - phase: 06-speed-typing-mode plan 00
    provides: stateFixture() helper in game_session_notifier_test.dart

provides:
  - GameMode.speedTyping enum value with GameModeDisplay extension
  - submitTyping(String input, List<StateData> states) action on GameSessionNotifier
  - skipCountdown:bool=false parameter on startGame()
  - high_score_speed_typing SharedPreferences key in HighScoreRepository
  - All exhaustive switch sites updated for speedTyping (completion_screen, session_restore_card, map_screen)

affects: [06-02, 06-03]

tech-stack:
  added: []
  patterns:
    - "skipCountdown parameter on startGame(): skips 5-tick countdown, starts Stopwatch immediately, sets phase to playing"
    - "submitTyping() for-loop pattern: explicit for-loop over List<StateData>, no package:collection dependency"
    - "game-end condition via states.length: matches production (50) while being unit-testable with small fixtures"
    - "TDD RED->GREEN: tests written against GameMode.speedTyping before enum value exists; compile error confirms RED"

key-files:
  created: []
  modified:
    - lib/features/game/game_mode.dart
    - lib/core/data/high_score_repository.dart
    - lib/features/game/game_session_notifier.dart
    - lib/features/home/session_restore_card.dart
    - lib/features/map/completion_screen.dart
    - lib/features/map/map_screen.dart
    - test/features/game/game_session_notifier_test.dart

key-decisions:
  - "submitTyping() checks states.length (not hardcoded 50) for game-end: production behavior preserved (50 placeable states) while tests with 5-state fixture work correctly"
  - "state_data.dart imported in game_session_notifier.dart for StateData type parameter — not an ad module import; walled-garden rule preserved"
  - "map_screen.dart speedTyping case uses Grand Master settings (showLabels=false, showName=false) — MapScreen never receives speedTyping in production but must compile"
  - "session_restore_card.dart and completion_screen.dart updated atomically with enum addition to prevent exhaustive switch compile errors"

patterns-established:
  - "Pattern: add new GameMode → update all 5 exhaustive switch sites atomically (high_score_repository, completion_screen, session_restore_card, map_screen, displayName extension)"
  - "Pattern: skipCountdown path in startGame() — sets phase to playing before _ticker.start(), ensuring immediate playing state without countdown ticks"

requirements-completed:
  - TYPING-04
  - TYPING-05
  - TYPING-07
  - TYPING-08
  - TYPING-09

duration: 5min
completed: 2026-06-02
---

# Phase 6 Plan 01: Speed Typing Mode Business Logic Summary

**GameMode.speedTyping enum value, GameModeDisplay extension, submitTyping() notifier action, skipCountdown support, and high_score_speed_typing repository key — pure Dart business logic foundation for Speed Typing Mode**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-02T17:46:00Z
- **Completed:** 2026-06-02T17:51:00Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added `GameMode.speedTyping` to enum and `GameModeDisplay` extension with `displayName` getter for all 5 modes
- Added `skipCountdown: bool = false` parameter to `startGame()` enabling Speed Typing to bypass the 5-second countdown
- Added `submitTyping(String input, List<StateData> states)` method using explicit for-loop; handles hit/miss/duplicate; triggers `completeGame()` at game-end
- Updated all 5 exhaustive switch sites (`high_score_repository`, `completion_screen`, `session_restore_card`, `map_screen`, `displayName`) to include `speedTyping`
- Added 15 TDD tests (6 displayName + 9 submitTyping/skipCountdown) using RED-GREEN-REFACTOR; full suite: 42 tests passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Add GameMode.speedTyping + GameModeDisplay extension** - `e4c22d0` (feat)
2. **Task 2: Add skipCountdown to startGame() and submitTyping() action** - `de7a594` (feat)

**Plan metadata:** (docs commit below)

_Note: TDD tasks — tests written before implementation; RED compile errors confirmed before GREEN implementation_

## Files Created/Modified

- `lib/features/game/game_mode.dart` - Added `speedTyping` enum value and `GameModeDisplay` extension with `displayName` getter
- `lib/core/data/high_score_repository.dart` - Added `GameMode.speedTyping => 'high_score_speed_typing'` to `_key()` switch
- `lib/features/game/game_session_notifier.dart` - Added `skipCountdown` param to `startGame()`, added `submitTyping()` method, imported `state_data.dart`
- `lib/features/home/session_restore_card.dart` - Added `speedTyping` case to `_modeLabel()` switch (Rule 3 fix)
- `lib/features/map/completion_screen.dart` - Added `speedTyping => Color(0xFF00695C)` to `_modeColor()` switch (Rule 3 fix)
- `lib/features/map/map_screen.dart` - Added `speedTyping` case (showLabels=false, showName=false) to mode matrix (Rule 3 fix)
- `test/features/game/game_session_notifier_test.dart` - Added `GameModeDisplay.displayName` group (6 tests) and `submitTyping` group (9 tests + 1 skipCountdown)

## Decisions Made

- `submitTyping()` checks `states.length` not hardcoded `50` for game-end trigger: testable with small fixtures; equivalent in production where states list always has 50 placeable entries
- `state_data.dart` import added to `game_session_notifier.dart` for `StateData` type — this is a core model import, not an ad module import; walled-garden rule strictly preserved (confirmed: zero ad imports)
- `map_screen.dart` `speedTyping` case uses Grand Master settings (no labels, no name) — MapScreen will never receive `speedTyping` in production, but Dart exhaustive switch requires all cases

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed exhaustive switch compile errors in session_restore_card.dart, completion_screen.dart, map_screen.dart**
- **Found during:** Task 1 (after adding speedTyping to enum)
- **Issue:** Adding `GameMode.speedTyping` to the enum immediately caused Dart exhaustiveness errors in 3 files not mentioned in Task 1's `<files>` list
- **Fix:** Added `speedTyping` case to each file's switch expression/statement
- **Files modified:** `lib/features/home/session_restore_card.dart`, `lib/features/map/completion_screen.dart`, `lib/features/map/map_screen.dart`
- **Verification:** `flutter analyze lib/` returns no exhaustiveness errors; all notifier tests pass
- **Committed in:** `e4c22d0` (Task 1 commit — plan noted these must be updated atomically in RESEARCH.md)

---

**Total deviations:** 1 auto-fixed (Rule 3 blocking — exhaustive switch errors)
**Impact on plan:** Required for compilation. Documented in RESEARCH.md §Exhaustiveness Analysis as expected fix sites. No scope creep.

## Issues Encountered

None — exhaustive switch fixes were anticipated in RESEARCH.md and handled atomically.

## Known Stubs

None — this plan delivers pure business logic with no UI stubs. `submitTyping()` is fully implemented.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. All changes are pure Dart business logic. COPPA compliance unaffected.

## Next Phase Readiness

- Wave 1 complete: `GameMode.speedTyping`, `displayName` extension, `submitTyping()`, `skipCountdown` all available
- Wave 2 (Plan 02: SpeedTypingScreen widget) can now:
  - Call `startGame(GameMode.speedTyping, skipCountdown: true)` 
  - Call `submitTyping(input, mapData.states)` and react to `bool` return
  - Use `GameMode.speedTyping.displayName` for app bar title
- Wave 2 (Plan 03: HomeScreen + routing) can wire the `/type` route and Mode 5 card
- No blockers for Wave 2 plans

## Self-Check: PASSED

- `lib/features/game/game_mode.dart` exists and contains 'speedTyping': FOUND
- `lib/core/data/high_score_repository.dart` contains 'high_score_speed_typing': FOUND
- `lib/features/game/game_session_notifier.dart` contains 'bool submitTyping': FOUND
- Commit `e4c22d0` exists: FOUND
- Commit `de7a594` exists: FOUND
- flutter test test/features/game/game_session_notifier_test.dart: 42 tests PASSED

---
*Phase: 06-speed-typing-mode*
*Completed: 2026-06-02*
