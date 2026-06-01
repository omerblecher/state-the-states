---
plan: "05-06"
phase: "05-polish-welcome-accessibility"
status: complete
completed: "2026-06-01"
duration: "3min"
tasks_completed: 2
files_modified: 3
subsystem: home-screen-session-restore
tags: [home, session-restore, TDD, A11Y, HOME-03]
dependency_graph:
  requires: ["05-03"]
  provides: ["SessionRestoreCard widget", "HOME-03 resume card on HomeScreen", "home_screen_test HOME-03 group"]
  affects:
    - lib/features/home/home_screen.dart
    - lib/features/home/session_restore_card.dart
    - test/features/home/home_screen_test.dart
tech_stack:
  added: []
  patterns:
    - "FutureBuilder<record-type>? wrapping optional card above mode ListView"
    - "StatelessWidget restore card with VoidCallback onContinue/onDismiss"
    - "Semantics root wrapper on card with label carrying mode + score"
    - "_formatElapsed identical to GameHud: remainder(60) minutes + % 60 seconds"
    - "MockGameStateRepository for HOME-03 widget tests"
key_files:
  created:
    - lib/features/home/session_restore_card.dart
  modified:
    - lib/features/home/home_screen.dart
    - test/features/home/home_screen_test.dart
decisions:
  - "SessionRestoreCard is StatelessWidget (not ConsumerWidget) — all Riverpod reads happen in HomeScreen; card just receives callbacks"
  - "Inline list literal in ProviderScope overrides avoids the Override type-annotation issue (Override is not re-exported from flutter_riverpod public API in this version)"
  - "FutureBuilder placed before Header Padding inside _buildBody Column — no structural change to rest of screen"
metrics:
  duration: "3min"
  completed_date: "2026-06-01"
---

# Phase 5 Plan 6: Session Restore Card (HOME-03) — Summary

## What Was Built

`HomeScreen` now shows a "Resume" card above the mode list when `GameStateRepository.loadSession()` returns a non-null saved session. The card displays mode name, score, MM:SS elapsed time, and states placed count (N / 50). Continue calls `restoreGame()` on the notifier then navigates to `/play`; Dismiss calls `clearSession()` and rebuilds the screen via `setState`. When no session exists the card is absent.

## Key Files

### Created
- `lib/features/home/session_restore_card.dart` — `SessionRestoreCard extends StatelessWidget`; accepts `session`, `hintPenalty`, `onContinue`, `onDismiss`; dark blue-grey gradient card matching `_ModeCard` decoration; `_formatElapsed` identical to `GameHud`; mode label switch covering all four `GameMode` values; root `Semantics` wrapper with mode + score label; CONTINUE `ElevatedButton` and Dismiss `TextButton` each wrapped in `Semantics(button: true, ...)`

### Modified
- `lib/features/home/home_screen.dart` — Added imports for `game_state_repository.dart`, `game_session.dart`, `game_session_notifier.dart`, `session_restore_card.dart`; added `FutureBuilder<({GameSession session, int hintPenalty})?>` at the top of `_buildBody` Column children; `onContinue` calls `restoreGame()` then `context.go('/play', extra: mode)`; `onDismiss` calls `clearSession()` then `setState()`
- `test/features/home/home_screen_test.dart` — Added `MockGameStateRepository`; updated `buildHomeScreen` helper to accept optional `mockGameStateRepo`; added `SessionRestoreCard` unit test group (5 tests); added `HomeScreen session restore (HOME-03)` group (3 tests); registered `GameSession` fallback value in `setUpAll`

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| RED | Failing tests for SessionRestoreCard and HOME-03 restore card | e34bad0 |
| GREEN (Task 1 + 2) | SessionRestoreCard widget + HomeScreen FutureBuilder + test fixes | 1c83471 |

## Verification

- `flutter test test/features/home/home_screen_test.dart` — 12/12 tests pass (4 original + 5 SessionRestoreCard unit + 3 HOME-03)
- `flutter analyze lib/features/home/` — No issues found

## Decisions Made

1. **SessionRestoreCard is StatelessWidget (not ConsumerWidget):** All Riverpod reads occur in `HomeScreen._buildBody()`; the card receives pre-resolved callbacks. This keeps the card simpler and easier to unit-test without ProviderScope.

2. **Inline ProviderScope overrides list:** Using an inline `[...]` literal in `ProviderScope(overrides: [...])` avoids the `Override` type annotation issue. The `Override` type is not part of `flutter_riverpod`'s re-exported public API at the version in use, causing a compile error when used as a local variable type.

3. **FutureBuilder positioned before Header Padding:** The restore card appears above the header row per the plan spec. No other structural changes to `_buildBody`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Compile] Fixed `Override` type annotation in test helper**
- **Found during:** Task 1/2 GREEN verify (first `flutter test` run)
- **Issue:** `final overrides = <Override>[...]` in `buildHomeScreen()` helper failed to compile — `Override` is not a publicly re-exported type from `flutter_riverpod` at the project version
- **Fix:** Changed to inline list literal directly in `ProviderScope(overrides: [...])`, eliminating the explicit typed local variable
- **Files modified:** `test/features/home/home_screen_test.dart`
- **Commit:** 1c83471 (included in GREEN commit)

## TDD Gate Compliance

- RED gate: `test(05-06)` commit `e34bad0` — Tests failed to compile (file missing), confirming RED state
- GREEN gate: `feat(05-06)` commit `1c83471` — All 12 tests pass

## Known Stubs

None — `SessionRestoreCard` is fully wired. `onContinue` calls real `restoreGame()` + `context.go('/play')`; `onDismiss` calls real `clearSession()` + `setState()`.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes. `loadSession()` reads local SharedPreferences only (T-05-13 already mitigated in Phase 2 D-08 try/catch).

## Self-Check: PASSED

- `lib/features/home/session_restore_card.dart` — exists, contains `SessionRestoreCard`, `_formatElapsed`, `_modeLabel`, CONTINUE button, Dismiss button, Semantics wrapper
- `lib/features/home/home_screen.dart` — contains `FutureBuilder`, `loadSession()`, `restoreGame`, `clearSession`, `session_restore_card.dart` import
- `test/features/home/home_screen_test.dart` — contains `HOME-03` test group, `MockGameStateRepository`, `SessionRestoreCard` tests
- Commits e34bad0, 1c83471 verified in git log
