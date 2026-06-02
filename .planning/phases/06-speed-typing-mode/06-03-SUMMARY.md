---
phase: 06-speed-typing-mode
plan: "03"
subsystem: game
tags: [flutter, dart, riverpod, home_screen, routing, tdd, widget_test, go_router]

requires:
  - phase: 06-speed-typing-mode plan 01
    provides: GameMode.speedTyping, GameModeDisplay.displayName, exhaustive switch fixes
  - phase: 06-speed-typing-mode plan 02
    provides: SpeedTypingScreen at lib/features/typing/speed_typing_screen.dart

provides:
  - GoRoute(path: '/type', SpeedTypingScreen) registered in app.dart
  - HomeScreen Mode 5 _ModeCard (Speed Typing, Icons.keyboard, 0xFF00695C)
  - HomeScreen onContinue mode-aware routing (speedTyping → /type, others → /play)
  - CompletionScreen displayName in AppBar title and Mode stat row
  - CompletionScreen Play Again mode-aware routing (speedTyping → /type, others → /play)
  - TYPING-01 widget test: 5 mode cards assertion
  - TYPING-02 widget test: Speed Typing card navigates to /type

affects: [06-04]

tech-stack:
  added: []
  patterns:
    - "skipOffstage: false in find.text() for off-screen ListView items in constrained test viewport"
    - "scrollUntilVisible() before tapping off-screen mode cards in 5-card ListView"
    - "Stub route (/type → Scaffold stub) in navigation tests avoids pumpAndSettle timeout from SpeedTypingScreen providers"
    - "Mode-aware routing: saved.session.mode == GameMode.speedTyping ? '/type' : '/play'"

key-files:
  created: []
  modified:
    - lib/features/map/completion_screen.dart
    - lib/features/home/home_screen.dart
    - lib/app.dart
    - test/features/home/home_screen_test.dart

key-decisions:
  - "find.text('Speed Typing', skipOffstage: false) required for 5th card assertion — Mode 5 card is below viewport at default test device size (800x600) with ListView non-lazy rendering"
  - "Navigation test uses Scaffold stub for /type instead of real SpeedTypingScreen — avoids pumpAndSettle timeout caused by stateDataProvider FutureProvider without asset bundle in tests"
  - "Shows Best: N test fixed to mock getBestScore(GameMode.speedTyping) — 5th card added, causing unmocked call to return null (not Future<null>) which throws TypeError"
  - "completion_screen.dart was already fixed by Wave 1 for _modeColor() speedTyping case; only displayName and Play Again routing needed in this plan"
  - "session_restore_card.dart and map_screen.dart were already fully fixed in Wave 1; no changes needed in Task 1 for those files"

patterns-established:
  - "Pattern: skipOffstage: false needed for find.text() on items below fold in bounded ListView widget tests"
  - "Pattern: stub route approach for navigation tests that target screens with complex provider dependencies"

requirements-completed:
  - TYPING-01
  - TYPING-02
  - TYPING-08

duration: 10min
completed: 2026-06-02
---

# Phase 6 Plan 03: App Shell Integration Summary

**Full app shell wiring for Speed Typing Mode: /type GoRoute, HomeScreen Mode 5 card, mode-aware session restore routing, CompletionScreen displayName + Play Again routing, and TYPING-01/02 widget tests**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-06-02T18:06:13Z
- **Completed:** 2026-06-02T18:16:13Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Fixed CompletionScreen to use `displayName` (not `.name`) in AppBar title and Mode stat row
- Fixed CompletionScreen Play Again button to route `speedTyping` sessions to `/type`, all others to `/play`
- Added Mode 5 `_ModeCard` to HomeScreen (Speed Typing, Icons.keyboard, teal 0xFF00695C)
- Fixed HomeScreen `onContinue` to route `speedTyping` sessions to `/type`, others to `/play`
- Registered `GoRoute(path: '/type', builder: SpeedTypingScreen)` in `app.dart`
- Updated `home_screen_test.dart`: 5-card assertion (TYPING-01), navigation test (TYPING-02), Best:N mock fix
- TDD RED→GREEN: 2 failing tests confirmed before implementation; all 14 tests green after

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix CompletionScreen displayName + Play Again routing** - `b5c6d55` (feat)
2. **Task 2 RED: Failing tests for 5 cards and /type navigation** - `6aca110` (test)
3. **Task 2 GREEN: HomeScreen Mode 5 + /type route + test fixes** - `60beb85` (feat)

## Files Created/Modified

- `lib/features/map/completion_screen.dart` — 3 changes:
  - AppBar title: `.name` → `.displayName`
  - Mode stat row value: `.name` → `.displayName`
  - Play Again `onPressed`: hardcoded `/play` → mode-aware `/type` or `/play`
- `lib/features/home/home_screen.dart` — 2 changes:
  - Added Mode 5 `_ModeCard` after Grand Master card (Speed Typing, keyboard icon, teal)
  - Fixed `onContinue` callback to route `speedTyping` sessions to `/type`
- `lib/app.dart` — 2 changes:
  - Added `import 'features/typing/speed_typing_screen.dart'`
  - Added `GoRoute(path: '/type', builder: SpeedTypingScreen)` before `/complete`
- `test/features/home/home_screen_test.dart` — 4 changes:
  - Renamed `shows 4 mode cards` → `shows 5 mode cards`; added Speed Typing assertion (skipOffstage: false)
  - Added `Speed Typing card navigates to /type (TYPING-02)` test with stub route
  - Fixed `shows Best: N` mock to include `GameMode.speedTyping`
  - Added `go_router` import; removed unused `SpeedTypingScreen` import

## Decisions Made

- `find.text('Speed Typing', skipOffstage: false)` used because Mode 5 is below the viewport at the default 800×600 test device size — `ListView(children: [...])` renders all children eagerly but the 5th card is clipped out of frame
- Stub route `('/type' → plain Scaffold)` used for navigation test instead of real `SpeedTypingScreen` — real screen triggers `stateDataProvider` (loads assets, no bundle in unit tests), causing `pumpAndSettle` to timeout
- `getBestScore(GameMode.speedTyping)` mock added to `shows Best: N` test — without it, mocktail returns `Null` (not `Future<Null>`), causing `TypeError: type 'Null' is not a subtype of type 'Future<int?>'`
- Wave 1 already fixed `session_restore_card.dart` and `map_screen.dart` exhaustiveness; no additional changes needed in Task 1

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing test regression: shows Best: N when score available**
- **Found during:** Task 2 GREEN (first test run after adding Mode 5 card)
- **Issue:** `shows Best: N` test only mocked 4 modes; Mode 5 card added `getBestScore(GameMode.speedTyping)` call, returning `Null` from mocktail (no `thenAnswer`) — TypeError at runtime
- **Fix:** Added `when(() => mockRepo.getBestScore(GameMode.speedTyping)).thenAnswer((_) async => null)` to the test
- **Files modified:** `test/features/home/home_screen_test.dart`
- **Committed in:** `60beb85`

**2. [Rule 1 - Bug] skipOffstage: false required for Speed Typing text assertion**
- **Found during:** Task 2 GREEN (test run showing 0 matches for `find.text('Speed Typing')`)
- **Issue:** Mode 5 card is below the viewport in the constrained test widget; `find.text()` defaults to `skipOffstage: true` which skips off-screen items
- **Fix:** Used `find.text('Speed Typing', skipOffstage: false)` for the 5-card assertion; added `scrollUntilVisible()` before the navigation tap
- **Files modified:** `test/features/home/home_screen_test.dart`
- **Committed in:** `60beb85`

**3. [Rule 1 - Bug] Navigation test pumpAndSettle timeout with real SpeedTypingScreen**
- **Found during:** Task 2 GREEN (test timed out after 4 seconds)
- **Issue:** Real `SpeedTypingScreen` loads `stateDataProvider` (asset-backed FutureProvider); test environment has no asset bundle, so provider never resolves, causing `pumpAndSettle` to timeout
- **Fix:** Used stub route (`Scaffold` with `Text('SpeedTypingStub')`) instead of `SpeedTypingScreen`; removed `SpeedTypingScreen` import from test file
- **Files modified:** `test/features/home/home_screen_test.dart`
- **Committed in:** `60beb85`
- **Plan note:** Plan §Task 2 action explicitly anticipates this: "Note: If GoRouter test infrastructure is complex, assert that find.text('Speed Typing') appears in the appbar of the destination screen instead."

---

**Total deviations:** 3 auto-fixed (Rule 1 bugs discovered during GREEN phase test runs)
**Impact on plan:** All fixes stay within Task 2 scope. No scope change. The stub route approach is explicitly permitted by the plan.

## Pre-existing Test Failures (Not Regressions)

5 tests were failing before this plan and remain failing — not caused by this plan:
- `state_tray_test.dart`: 3 failures (pre-existing state tray rendering issues)
- `usa_map_painter_test.dart`: 1 compile/load failure (pre-existing `insetFrameRects` API change)
- `welcome_screen_test.dart`: 1 A11Y failure (pre-existing labeled tap target issue)

## Known Stubs

None — all routing is wired to real screens. The `/type` route points to the real `SpeedTypingScreen` in `app.dart`. The stub route is test-only.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. COPPA compliance unaffected: no Firebase imports, no persistent identifiers, no ad calls.

## Self-Check: PASSED

- `lib/app.dart` contains `'/type'`: FOUND
- `lib/app.dart` imports `speed_typing_screen.dart`: FOUND
- `lib/features/home/home_screen.dart` contains `GameMode.speedTyping`: FOUND
- `lib/features/home/home_screen.dart` contains `Icons.keyboard`: FOUND
- `lib/features/home/home_screen.dart` onContinue contains `speedTyping` and `/type`: FOUND
- `lib/features/map/completion_screen.dart` contains `.displayName` (2 occurrences): FOUND
- `lib/features/map/completion_screen.dart` Play Again contains `speedTyping` and `/type`: FOUND
- Commit `b5c6d55` exists: FOUND
- Commit `6aca110` exists: FOUND
- Commit `60beb85` exists: FOUND
- flutter test test/features/home/home_screen_test.dart: 14 tests PASSED
- Full suite: 152 passing, 5 pre-existing failures (no regressions)

---
*Phase: 06-speed-typing-mode*
*Completed: 2026-06-02*
