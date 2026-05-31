---
phase: 02-state-machine-repositories
plan: 01
subsystem: game
tags: [dart, enums, value-object, tdd, ticker, riverpod]

requires:
  - phase: 01-foundation
    provides: Project scaffold, pubspec.yaml with all dependencies, state_data.dart postal canonical key

provides:
  - GamePhase enum (idle/countdown/playing/paused/completed)
  - GameMode enum (learn/statesMaster/geographicalMaster/grandMaster) with statesMaster rename
  - GameSession value object with activePostal/matchedPostals, copyWith sentinel, ==, hashCode
  - Ticker/RealTicker/FakeTicker seam for deterministic test control

affects:
  - 02-02 (GameSessionNotifier imports GameSession, GamePhase, GameMode, Ticker)
  - 02-03 (notifier + observer)
  - 02-04 (repositories that use GameSession and GameMode)

tech-stack:
  added: []
  patterns:
    - "Sentinel copyWith: static const Object _sentinel = Object() enables nullable field clear via copyWith(field: null)"
    - "FakeTicker seam: FakeTicker.tick() drives deterministic tests without real Timer.periodic"
    - "Enum rename pattern: flagsMaster → statesMaster applied to enum + all downstream SharedPreferences keys"

key-files:
  created:
    - lib/features/game/game_phase.dart
    - lib/features/game/game_mode.dart
    - lib/features/game/game_session.dart
    - lib/core/ticker.dart
    - test/features/game/game_session_test.dart
  modified: []

key-decisions:
  - "statesMaster rename applied (flagsMaster removed everywhere) — affects high_score_repository.dart key in Plan 02"
  - "hintPenalty NOT a field on GameSession — it is notifier-internal state persisted separately in snapshot (Plan 02)"
  - "FakeTicker controls tick delivery; real Stopwatch in notifier is not injected — isRunning verification suffices for pause tests"

patterns-established:
  - "Sentinel copyWith pattern: static const Object _sentinel = Object() for nullable field pass-through"
  - "Pure value object: no notifier-internal state (hintPenalty stays in notifier), keeps GameSession a clean model"

requirements-completed: [SCORE-01, SCORE-02, SESS-03]

duration: 15min
completed: 2026-05-31
---

# Phase 02 Plan 01: State Machine Contracts Summary

**Pure-Dart GamePhase/GameMode enums, GameSession value object with postal renames + sentinel copyWith, and Ticker/RealTicker/FakeTicker seam — all contracts downstream plans import directly**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-31T00:00:00Z
- **Completed:** 2026-05-31
- **Tasks:** 2 (Task 1: enums + Ticker; Task 2: GameSession + tests — TDD)
- **Files modified:** 5 created, 0 modified

## Accomplishments

- GamePhase and GameMode enums ported verbatim from Flags, with `flagsMaster` → `statesMaster` rename applied to GameMode
- Ticker/RealTicker/FakeTicker seam ported verbatim — FakeTicker exposes public `tick()` for deterministic test control
- GameSession value object ported with `activeIsoCode` → `activePostal` and `matchedIsoCodes` → `matchedPostals` renames; sentinel copyWith, `_listEquals`, `==`, and `hashCode` all correct
- 8 unit tests written (TDD RED/GREEN cycle) covering equality, hashCode, copyWith field-replace, sentinel null-clear, and list equality

## Task Commits

1. **Task 1: Port GamePhase, GameMode enums and Ticker seam** - `4de3822` (feat)
2. **Task 2 RED: Failing GameSession tests** - `494c856` (test)
3. **Task 2 GREEN: GameSession implementation** - `5371750` (feat)

## TDD Gate Compliance

- RED gate commit exists: `494c856` (test(02-01): add failing GameSession equality/copyWith sentinel tests)
- GREEN gate commit exists: `5371750` (feat(02-01): implement GameSession value object with postal renames)
- No REFACTOR needed — implementation was clean

## Files Created/Modified

- `lib/features/game/game_phase.dart` — GamePhase enum with 5 values (verbatim port)
- `lib/features/game/game_mode.dart` — GameMode enum with statesMaster rename
- `lib/core/ticker.dart` — Ticker abstraction with RealTicker (Timer.periodic 1s) and FakeTicker (test seam)
- `lib/features/game/game_session.dart` — GameSession value object with sentinel copyWith, postal renames, ==, hashCode
- `test/features/game/game_session_test.dart` — 8 unit tests for GameSession equality + copyWith sentinel behavior

## Decisions Made

- `hintPenalty` is NOT a field on `GameSession` — it is notifier-internal state (`_hintPenalty`) stored separately in the snapshot JSON as an explicit field (D-05). This keeps `GameSession` a pure value object.
- `statesMaster` rename applied in `game_mode.dart`; the corresponding `high_score_repository.dart` key change (`high_score_states_master`) is Plan 02's responsibility.
- `FakeTicker` controls tick delivery but does not fake the `Stopwatch` — pause/resume tests verify `Stopwatch.isRunning` state rather than elapsed values (RESEARCH.md Pitfall 2 resolution).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All four contracts (`GamePhase`, `GameMode`, `GameSession`, `Ticker`) compile and are importable by Plan 02 (repositories) and Plan 03 (notifier + observer)
- `flutter analyze` exits 0 on all created files
- All 8 `GameSession` unit tests pass
- No `isoCode` tokens remain in `lib/features/game/`
- No `flagsMaster` token in the codebase

---
*Phase: 02-state-machine-repositories*
*Completed: 2026-05-31*
