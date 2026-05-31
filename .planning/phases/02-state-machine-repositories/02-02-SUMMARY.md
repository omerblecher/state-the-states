---
phase: 02-state-machine-repositories
plan: 02
subsystem: database
tags: [shared_preferences, repository, persistence, dart, flutter, riverpod, tdd]

# Dependency graph
requires:
  - phase: 02-state-machine-repositories/02-01
    provides: GamePhase, GameMode, GameSession value object, Ticker seam

provides:
  - GameStateRepository interface + SharedPreferences implementation with explicit hintPenalty field (D-05) and silent-discard with key-clear (D-08)
  - HighScoreRepository interface + SharedPreferences implementation with lower-wins guard and statesMaster key
  - UserPrefsRepository interface + SharedPreferences implementation with mute and tutorial-seen persistence
  - Six unit tests covering round-trip identity, corrupt-discard, lower-wins sequence, cold-read, mute defaults, and tutorial persistence

affects:
  - 02-03 (GameSessionNotifier consumes all three repository interfaces)
  - 02-04 (audio hardening does not depend on repositories, but same wave)
  - Phase 5 (session restore uses loadSession + restoreGame; tutorial-seen gating uses UserPrefsRepository)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - abstract interface class + SharedPreferencesXRepository implements XRepository (all three repos)
    - FutureProvider<XRepository> wrapping SharedPreferences.getInstance() (all three repos)
    - Dart 3.x named record return type ({GameSession session, int hintPenalty}) for loadSession()
    - TDD RED/GREEN per task (failing test commit then implementation commit)
    - SharedPreferences.setMockInitialValues({}) + TestWidgetsFlutterBinding.ensureInitialized() for persistence tests

key-files:
  created:
    - lib/core/data/game_state_repository.dart
    - lib/core/data/high_score_repository.dart
    - lib/core/data/user_prefs_repository.dart
    - test/core/data/game_state_repository_test.dart
    - test/core/data/high_score_repository_test.dart
    - test/core/data/user_prefs_repository_test.dart
    - lib/features/game/game_phase.dart
    - lib/features/game/game_mode.dart
    - lib/features/game/game_session.dart
    - lib/core/ticker.dart
    - test/features/game/game_session_test.dart
  modified: []

key-decisions:
  - "hintPenalty is an explicit first-class JSON field in the snapshot (D-05) — never back-calculated from other fields"
  - "loadSession() catch block calls _prefs.remove(_key) before returning null (D-08) — Flags omitted this, preventing repeat parse failures"
  - "HighScoreRepository uses statesMaster key ('high_score_states_master') replacing Flags' 'high_score_flags_master'"
  - "lower-wins guard is strict less-than (score < current) — equal score does not overwrite"
  - "GameSession.hintPenalty is NOT a field on the model — it remains notifier-internal per RESEARCH.md §3, persisted only through saveSession()"

patterns-established:
  - "Repository pattern: abstract interface class + SharedPreferencesXRepository implements, injected via FutureProvider"
  - "Dart 3.x named record for multi-value repository returns: Future<({T session, int hintPenalty})?>?"
  - "Silent-discard with key clear: try/catch in loadSession catches all errors, removes key, returns null"
  - "SharedPreferences test pattern: setMockInitialValues({}) in setUp, getInstance() per test"

requirements-completed: [SCORE-05, SESS-02, SESS-03]

# Metrics
duration: 25min
completed: 2026-05-31
---

# Phase 2 Plan 02: Repositories Summary

**Three SharedPreferences-backed repositories (GameStateRepository with D-05 hintPenalty + D-08 key-clear, HighScoreRepository lower-wins golf scoring, UserPrefsRepository mute/tutorial) with 17 green unit tests**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-31
- **Completed:** 2026-05-31
- **Tasks:** 2 (plan 02-02) + 1 deviation (Wave 1 prereqs)
- **Files modified:** 11 created, 0 modified

## Accomplishments
- GameStateRepository: snapshot save/load/clear with explicit hintPenalty (D-05) and silent-discard key-clear (D-08), round-trip tested
- HighScoreRepository: lower-wins golf scoring guard, statesMaster key rename, cold-read tested
- UserPrefsRepository: mute + tutorial-seen persistence, both default-false, persistence tested
- Wave 1 dependency types created as blocking deviation (GamePhase, GameMode, GameSession, Ticker) — these were tracked as complete in STATE.md but were absent from the worktree

## Task Commits

Each task was committed atomically:

**Deviation (blocking prereq):**
- `14e72ed` feat(02-02): add Wave 1 dependency types (GamePhase, GameMode, GameSession, Ticker)

**Task 1 — GameStateRepository (TDD):**
- `82a7267` test(02-02): add failing tests for GameStateRepository (RED)
- `d677cd8` feat(02-02): implement GameStateRepository with explicit hintPenalty + silent-discard (GREEN)

**Task 2 — HighScoreRepository + UserPrefsRepository (TDD):**
- `9c340a9` test(02-02): add failing tests for HighScoreRepository + UserPrefsRepository (RED)
- `76f2207` feat(02-02): implement HighScoreRepository (lower-wins, statesMaster) + UserPrefsRepository (mute) (GREEN)

## Files Created/Modified
- `lib/features/game/game_phase.dart` — GamePhase enum (idle/countdown/playing/paused/completed)
- `lib/features/game/game_mode.dart` — GameMode enum (learn/statesMaster/geographicalMaster/grandMaster)
- `lib/features/game/game_session.dart` — GameSession value object with activePostal/matchedPostals, sentinel copyWith, ==/hashCode
- `lib/core/ticker.dart` — Ticker abstract class + RealTicker (Timer.periodic) + FakeTicker (test seam)
- `lib/core/data/game_state_repository.dart` — GameStateRepository interface + SharedPreferences impl + FutureProvider
- `lib/core/data/high_score_repository.dart` — HighScoreRepository interface + SharedPreferences impl + FutureProvider
- `lib/core/data/user_prefs_repository.dart` — UserPrefsRepository interface + SharedPreferences impl + FutureProvider
- `test/features/game/game_session_test.dart` — GameSession equality/copyWith/sentinel/list tests (7 tests)
- `test/core/data/game_state_repository_test.dart` — Round-trip, absent key, corrupt+clear, clearSession (4 tests)
- `test/core/data/high_score_repository_test.dart` — Never-written null, lower-wins 20->25->15=15, cold-read, mode independence (5 tests)
- `test/core/data/user_prefs_repository_test.dart` — getMuted default, setMuted persists, toggle, fresh instance, tutorial (6 tests)

## Decisions Made
- hintPenalty stored as explicit first-class JSON field (D-05) — plan requires this; notifier passes it in, never back-calculates
- D-08 key-clear in catch: `await _prefs.remove(_key)` before returning null prevents repeat failures on next app launch
- HighScoreRepository lower-wins guard is strict `score < current` — equal score does not overwrite (deterministic)
- UserPrefsRepository carries getTutorialSeen/setTutorialSeen for Phase 5 even though only mute is exercised this phase

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created Wave 1 dependency types missing from worktree**
- **Found during:** Pre-execution check (before Task 1)
- **Issue:** lib/features/game/ directory did not exist in worktree; GamePhase, GameMode, GameSession, and lib/core/ticker.dart were all absent. STATE.md/ROADMAP.md had been updated to show Wave 1 as complete, but no actual code was merged into this worktree branch. The repositories cannot compile without these types.
- **Fix:** Created all four Wave 1 source files (GamePhase, GameMode, GameSession, Ticker) from plan 02-01 plus the GameSession unit test, exactly as specified in 02-01-PLAN.md and 02-PATTERNS.md.
- **Files modified:** lib/features/game/game_phase.dart, lib/features/game/game_mode.dart, lib/features/game/game_session.dart, lib/core/ticker.dart, test/features/game/game_session_test.dart
- **Verification:** flutter test test/features/game/game_session_test.dart exits 0 (7/7 passing); flutter analyze exits 0
- **Committed in:** 14e72ed (pre-task 1 deviation commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking)
**Impact on plan:** Necessary unblock; no scope creep. All Wave 1 types exactly match 02-01-PLAN.md specifications.

## Issues Encountered
None beyond the Wave 1 missing-files deviation documented above.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- All three repository interfaces are ready for Plan 03 (GameSessionNotifier) to consume
- gameStateRepositoryProvider, highScoreRepositoryProvider, userPrefsRepositoryProvider are all declared and injectable
- loadSession() returns a Dart 3.x named record — Plan 03's restoreGame() reads (.session, .hintPenalty) directly
- 24/24 tests passing across all repository + model files in this wave

---
*Phase: 02-state-machine-repositories*
*Completed: 2026-05-31*

## Self-Check: PASSED

- lib/core/data/game_state_repository.dart: FOUND
- lib/core/data/high_score_repository.dart: FOUND
- lib/core/data/user_prefs_repository.dart: FOUND
- test/core/data/game_state_repository_test.dart: FOUND
- test/core/data/high_score_repository_test.dart: FOUND
- test/core/data/user_prefs_repository_test.dart: FOUND
- .planning/phases/02-state-machine-repositories/02-02-SUMMARY.md: FOUND
- Commit 14e72ed (Wave 1 prereqs): FOUND
- Commit 82a7267 (GameStateRepo RED): FOUND
- Commit d677cd8 (GameStateRepo GREEN): FOUND
- Commit 9c340a9 (HighScore+UserPrefs RED): FOUND
- Commit 76f2207 (HighScore+UserPrefs GREEN): FOUND
