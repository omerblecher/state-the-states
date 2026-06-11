---
phase: quick-260611-tql
plan: "01"
subsystem: map
tags: [bug-fix, session-restore, game-state]
dependency_graph:
  requires: []
  provides: [session-restore-correct-state]
  affects: [lib/features/map/map_screen.dart, test/features/map/map_screen_test.dart]
tech_stack:
  added: []
  patterns: [pre-seeded ProviderScope override for widget tests, FakeTicker in test helper notifier]
key_files:
  created: []
  modified:
    - lib/features/map/map_screen.dart
    - test/features/map/map_screen_test.dart
decisions:
  - "Use _RestoredSessionNotifier (GameSessionNotifier subclass with build() returning paused session) to avoid SharedPreferences I/O in widget tests"
  - "alreadyMatched derived once inside _startSequence via Set.from(session?.matchedPostals ?? const []) — null and empty share one code path"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_modified: 2
---

# Phase quick-260611-tql Plan 01: Fix Session Restore Bug in MapScreen Summary

**One-liner:** `_startSequence` now seeds `_matchedPostals` from `session.matchedPostals` and excludes already-matched postals from the playable pool, so restoring a paused session shows correct HUD progress and never re-prompts placed states.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Seed _startSequence from restored session | 523924b | lib/features/map/map_screen.dart |
| 2 | Add restore widget test | fb44655 | test/features/map/map_screen_test.dart |

## What Was Done

### Task 1 — Implementation

Changed `_startSequence(List<StateData> states)` to `_startSequence(List<StateData> states, GameSession? session)`.

Inside the method (after `_sequenceInitialized = true`):
- Derive `alreadyMatched = Set<String>.from(session?.matchedPostals ?? const [])` — defaults to empty for fresh games (null or empty list).
- Assign `_matchedPostals = alreadyMatched` so `GameHud` progress count and `UsaMapPainter` state colors reflect the restored position immediately.
- Filter the playable list: `where((s) => s.postal != 'DC' && !alreadyMatched.contains(s.postal))` — already-matched states are excluded from `_remainingPostals` before shuffling.

Updated call site in `_buildMapStack` from `_startSequence(states)` to `_startSequence(states, session)`.

`_maybeStartGame` was not touched — its existing `phase != idle && phase != completed → return` guard already prevents overriding a `paused` restore with a fresh `startGame()` call.

### Task 2 — Widget Test

Added `testWidgets('MapScreen restores session: HUD shows matchedCount=2 and painter has CA+TX matched')` to `test/features/map/map_screen_test.dart`.

Approach chosen: `_RestoredSessionNotifier` (subclass of `GameSessionNotifier`) whose `build()` returns the pre-constructed paused session directly, bypassing SharedPreferences I/O entirely. Uses `FakeTicker` to avoid real timers.

Override structure: `ProviderScope(overrides: [stateDataProvider.overrideWith(...), gameSessionProvider.overrideWith(() => _RestoredSessionNotifier(restoredSession))])`.

Assertions:
- `tester.widget<GameHud>(...).matchedCount == 2`
- `find.byWidgetPredicate(... UsaMapPainter.matchedPostals.containsAll({'CA','TX'}))` finds at least one widget.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Initial test implementation timed out at 10 minutes**
- **Found during:** Task 2 verification
- **Issue:** The first test implementation used `UncontrolledProviderScope` with a pre-seeded `ProviderContainer` and called `tester.runAsync(() => gameContainer.read(gameSessionProvider.future))`. The `gameSessionProvider` `build()` method awaits `gameStateRepositoryProvider` and `highScoreRepositoryProvider` (both backed by SharedPreferences), which hung in the test environment.
- **Fix:** Replaced with `_RestoredSessionNotifier` (a `GameSessionNotifier` subclass) whose `build()` returns the restored session immediately. This avoids all SharedPreferences I/O and eliminates the timeout.
- **Files modified:** `test/features/map/map_screen_test.dart`
- **Commit:** fb44655 (amended from 6377e20)

## Known Stubs

None — the fix wires real data; no placeholders introduced.

## Threat Flags

None — this change is internal widget state initialization (no new network, auth, file, or schema surface introduced).

## Self-Check

### Files exist
- `lib/features/map/map_screen.dart` — modified (signature change + call site update)
- `test/features/map/map_screen_test.dart` — modified (restore test + helper class)

### Commits exist
- 523924b — fix(quick-260611-tql-01): seed _startSequence from restored session matchedPostals
- 6377e20 — test(quick-260611-tql-01): verify session restore seeds matchedPostals in MapScreen [superseded]
- fb44655 — test(quick-260611-tql-01): fix restore test to avoid SharedPreferences timeout

### Test results
All 13 tests in `test/features/map/map_screen_test.dart` pass in ~2 seconds.

## Self-Check: PASSED
