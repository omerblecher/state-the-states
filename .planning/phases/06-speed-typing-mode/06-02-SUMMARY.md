---
phase: 06-speed-typing-mode
plan: "02"
subsystem: typing
tags: [flutter, dart, riverpod, widget, tdd, speed_typing, game_screen]

requires:
  - phase: 06-speed-typing-mode plan 00
    provides: test/features/typing/ directory and stateFixture() helper
  - phase: 06-speed-typing-mode plan 01
    provides: GameMode.speedTyping, submitTyping(), skipCountdown support

provides:
  - SpeedTypingScreen ConsumerStatefulWidget at lib/features/typing/speed_typing_screen.dart
  - Widget tests for TYPING-03 (TextCapitalization.characters) and TYPING-06 (chip grid)

affects: [06-03]

tech-stack:
  added: []
  patterns:
    - "SpeedTypingScreen lifecycle: GameLifecycleObserver mount in initState, removeObserver in dispose"
    - "_maybeStartGame guard: _gameStartRequested bool prevents duplicate startGame() across rebuilds"
    - "_navigationPending guard + addPostFrameCallback: prevents navigation during build phase (Pitfall 2)"
    - "previousBest fetched BEFORE completeGame(): preserves pre-completion score for high score comparison (Pitfall 8)"
    - "Chip lookup: explicit for-loop over List<StateData> without package:collection"
    - "TextField cleared immediately in _onSubmit before guards (D-03: clear on every submission)"
    - "TDD RED->GREEN: compile error on missing speed_typing_screen.dart confirms RED; file creation makes GREEN"

key-files:
  created:
    - lib/features/typing/speed_typing_screen.dart
  modified:
    - test/features/typing/speed_typing_screen_test.dart

key-decisions:
  - "dart:ui FontFeature.tabularFigures() available via package:flutter/material.dart — unnecessary dart:ui import removed (flutter_lints info)"
  - "use_build_context_synchronously on context.go after await chain: suppressed with // ignore comment; mounted check before context.go is semantically correct guard"
  - "Pause overlay implemented as Stack child (same pattern as MapScreen _buildPauseOverlay): reuses existing Riverpod pause/resume/endGame methods"
  - "_isMuted local state without SharedPreferences: follows MapScreen _toggleMute pattern exactly (toggle + audioService.setMuted)"

patterns-established:
  - "SpeedTypingScreen._maybeStartGame() reuses MapScreen guard pattern verbatim but with speedTyping + skipCountdown:true"
  - "SpeedTypingScreen chip grid: Wrap with explicit for-loop postal→name resolution (no firstWhereOrNull)"

requirements-completed:
  - TYPING-02
  - TYPING-03
  - TYPING-04
  - TYPING-06

duration: 8min
completed: 2026-06-02
---

# Phase 6 Plan 02: SpeedTypingScreen Widget Summary

**SpeedTypingScreen ConsumerStatefulWidget with TDD widget tests — teal AppBar, UPPERCASE TextField, scrollable found-states chip grid, and MapScreen-pattern lifecycle wiring**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-06-02T17:54:40Z
- **Completed:** 2026-06-02T18:02:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced Wave 0 stub in `test/features/typing/speed_typing_screen_test.dart` with 4 real widget tests covering TYPING-03 and TYPING-06
- Created `lib/features/typing/speed_typing_screen.dart` as `ConsumerStatefulWidget` with full lifecycle, HUD, chip grid, TextField, and navigation guard
- TDD RED phase confirmed via compile error (missing file import); GREEN phase achieved with all 4 tests passing
- Full test suite unchanged: 151 passing + 5 pre-existing failures (no regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write SpeedTypingScreen widget tests (RED phase)** - `f3cbc14` (test)
2. **Task 2: Create SpeedTypingScreen (GREEN phase)** - `92827ec` (feat)

**Plan metadata:** (docs commit below)

_Note: TDD tasks — tests written before implementation; RED compile errors confirmed before GREEN implementation_

## Files Created/Modified

- `lib/features/typing/speed_typing_screen.dart` — SpeedTypingScreen ConsumerStatefulWidget (new file, 413 lines):
  - `initState`: GameLifecycleObserver mount, WidgetsBinding.addObserver
  - `dispose`: removeObserver, TextEditingController.dispose
  - `_maybeStartGame()`: guard with `_gameStartRequested`, calls `startGame(GameMode.speedTyping, skipCountdown: true)`
  - `_onSubmit()`: clears controller, normalizes to uppercase, calls `submitTyping()`, plays correct/error audio
  - `_onPausePressed()`: calls `pauseGame()`, shows pause overlay
  - `_navigationPending` guard: fetches `previousBest` BEFORE `completeGame()`, navigates to `/complete`
  - HUD bar: score, matched count / 50, MM:SS timer, mute/pause buttons
  - Chip grid: `Wrap` of `Chip` widgets from `session.matchedPostals`, `Colors.green.shade700`, `FontWeight.w700`
  - TextField: `TextCapitalization.characters`, `enabled: mapDataAsync.hasValue`
  - AppBar: `Color(0xFF00695C)`, title 'Speed Typing', home leading button
- `test/features/typing/speed_typing_screen_test.dart` — 4 widget tests:
  - Test 1: AppBar title 'Speed Typing'
  - Test 2: `TextField.textCapitalization == TextCapitalization.characters` (TYPING-03)
  - Test 3: chip grid empty when `matchedPostals` empty (TYPING-06)
  - Test 4: Chip with label 'Georgia' appears when `matchedPostals: ['GA']` (TYPING-06)

## Decisions Made

- `dart:ui` import removed — `FontFeature.tabularFigures()` is re-exported by `package:flutter/material.dart`; lint `unnecessary_import` resolved
- `// ignore: use_build_context_synchronously` added at `context.go(...)` after async chain — the `if (!mounted) return` check immediately before is semantically correct; the lint cannot see through `State.mounted`
- Pause overlay rendered as `Stack` child wrapping `Scaffold` — same approach as MapScreen; no `Overlay.of()` needed for a simple blocking overlay

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing `game_session.dart` import caused compile error**
- **Found during:** Task 2 (first flutter test run after creating the file)
- **Issue:** `GameSession` type used in `_maybeStartGame(GameSession? session)` but `game_session.dart` was not in the import list
- **Fix:** Added `import '../../features/game/game_session.dart';`
- **Files modified:** `lib/features/typing/speed_typing_screen.dart`

**2. [Rule 1 - Bug] Unnecessary `dart:ui` import**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `import 'dart:ui' show FontFeature;` is redundant when `material.dart` is imported
- **Fix:** Removed the `dart:ui` import line
- **Files modified:** `lib/features/typing/speed_typing_screen.dart`

**3. [Rule 1 - Bug] `use_build_context_synchronously` lint on navigation after await chain**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `context.go(...)` called after `await repo.getBestScore(...)` and `await completeGame()` inside postFrameCallback
- **Fix:** Added `// ignore: use_build_context_synchronously` with `if (!mounted) return` guard immediately before — semantically correct per MapScreen pattern
- **Files modified:** `lib/features/typing/speed_typing_screen.dart`

---

**Total deviations:** 3 auto-fixed (Rule 1 bugs — compile error, lint warnings)
**Impact on plan:** All fixes required for compilation and lint-clean code. No scope change.

## Known Stubs

None — SpeedTypingScreen is fully wired to production providers. The `/type` route is not yet registered in `app.dart` (that is Plan 03's work), but the screen itself has no stubs.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Zero ad imports confirmed (`flutter analyze` passes with zero issues on `speed_typing_screen.dart`).

## Self-Check: PASSED

- `lib/features/typing/speed_typing_screen.dart` exists and contains 'class SpeedTypingScreen': FOUND
- File contains 'TextCapitalization.characters': FOUND
- File contains 'Colors.green.shade700': FOUND
- File contains 'FontWeight.w700': FOUND
- File contains 'addPostFrameCallback': FOUND
- File contains '_navigationPending': FOUND
- File contains 'startGame(GameMode.speedTyping, skipCountdown: true)': FOUND
- File does NOT contain any ad module import: CONFIRMED
- Commit `f3cbc14` exists: FOUND
- Commit `92827ec` exists: FOUND
- flutter test test/features/typing/speed_typing_screen_test.dart: 4 tests PASSED

---
*Phase: 06-speed-typing-mode*
*Completed: 2026-06-02*
